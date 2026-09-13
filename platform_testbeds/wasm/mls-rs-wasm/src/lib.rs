//! wasm-bindgen bindings for `mls-rs` backed by the RustCrypto
//! provider.
//!
//! The API mirrors `mls-rs-uniffi`: [`Client`] creation with basic or
//! X.509 credentials, key-package generation, group creation, member
//! add/remove, welcome-based joins and application-message
//! encryption. All five RustCrypto cipher suites (MLS suites 1, 2, 3,
//! 5 and 7) are supported.
//!
//! Randomness comes from the host CSPRNG (`globalThis.crypto` via
//! `getrandom`'s `js` backend).
//!
//! Storage: `WasmClient::new`/`newX509` keep group state and key
//! packages in memory (lost on reload). `WasmClient::openPersistent`
//! stores them in an IndexedDB database (`mls-rs-{name}`) whose values
//! are AES-256-GCM encrypted with an application-supplied 32-byte key
//! — the same model as Wire's CoreCrypto keystore. App data stays in
//! the app's own storage.
//!
//! Built without `mls_build_async` the exported API is synchronous
//! (IndexedDB writes happen in the background — see
//! [`WasmClient::flushStorage`]). Built with `RUSTFLAGS="--cfg
//! mls_build_async"` every method returning into mls-rs becomes a
//! JavaScript `Promise` and persistence writes are awaited inside each
//! call.

use std::fmt::Debug;
#[cfg(not(mls_build_async))]
use std::sync::Mutex;
#[cfg(mls_build_async)]
use tokio::sync::Mutex;

use mls_rs::client_builder::{self, WithGroupStateStorage};
use mls_rs::identity::basic::BasicIdentityProvider;
use mls_rs::mls_rules::{self, DefaultMlsRules};
#[cfg(not(target_family = "wasm"))]
use mls_rs::storage_provider::in_memory::{InMemoryGroupStateStorage, InMemoryKeyPackageStorage};
use mls_rs::{CipherSuiteProvider, CryptoProvider};
use mls_rs_core::error::IntoAnyError;
use mls_rs_core::identity::{
    Credential, CredentialType, IdentityProvider, MemberValidationContext, SigningIdentity,
};
use mls_rs_core::time::MlsTime;
use mls_rs_crypto_rustcrypto::x509::{X509Reader, X509Validator};
use mls_rs_crypto_rustcrypto::RustCryptoProvider;
use mls_rs_identity_x509::{
    DerCertificate, SubjectIdentityExtractor, X509IdentityError, X509IdentityProvider,
};
use wasm_bindgen::prelude::*;

/// Evaluate an expression that is a future in `mls_build_async` builds
/// and a plain call in sync builds.
macro_rules! maybe_await {
    ($e:expr) => {{
        #[cfg(mls_build_async)]
        {
            $e.await
        }
        #[cfg(not(mls_build_async))]
        {
            $e
        }
    }};
}

/// MLS cipher suites supported by the RustCrypto backend.
///
/// The numeric values match the MLS cipher suite identifiers in
/// RFC 9420.
#[wasm_bindgen]
#[derive(Copy, Clone, Debug)]
#[repr(u16)]
pub enum WasmCipherSuite {
    /// `MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519`
    Curve25519Aes128 = 1,
    /// `MLS_128_DHKEMP256_AES128GCM_SHA256_P256`
    P256Aes128 = 2,
    /// `MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519`
    Curve25519ChaCha = 3,
    /// `MLS_256_DHKEMP521_AES256GCM_SHA512_P521`
    P521Aes256 = 5,
    /// `MLS_256_DHKEMP384_AES256GCM_SHA384_P384`
    P384Aes256 = 7,
}

impl From<WasmCipherSuite> for mls_rs::CipherSuite {
    fn from(suite: WasmCipherSuite) -> Self {
        match suite {
            WasmCipherSuite::Curve25519Aes128 => mls_rs::CipherSuite::CURVE25519_AES128,
            WasmCipherSuite::P256Aes128 => mls_rs::CipherSuite::P256_AES128,
            WasmCipherSuite::Curve25519ChaCha => mls_rs::CipherSuite::CURVE25519_CHACHA,
            WasmCipherSuite::P521Aes256 => mls_rs::CipherSuite::P521_AES256,
            WasmCipherSuite::P384Aes256 => mls_rs::CipherSuite::P384_AES256,
        }
    }
}

/// Identity provider dispatching between basic credentials and X.509
/// certificate credentials (validated with the RustCrypto X.509
/// validator against a caller-provided root CA list).
#[derive(Clone, Debug)]
struct WasmIdentityProvider {
    basic: BasicIdentityProvider,
    x509: X509IdentityProvider<SubjectIdentityExtractor<X509Reader>, X509Validator>,
}

#[derive(Debug, thiserror::Error)]
enum WasmIdentityProviderError {
    #[error(transparent)]
    AnyError(#[from] mls_rs_core::error::AnyError),
    #[error("unsupported credential type: {0:?}")]
    UnsupportedCredentialType(CredentialType),
}

impl IntoAnyError for WasmIdentityProviderError {
    fn into_dyn_error(self) -> Result<Box<dyn std::error::Error + Send + Sync>, Self> {
        Ok(self.into())
    }
}

struct ClientOptions {
    root_ca_certificates: Vec<Vec<u8>>,
    allow_self_signed_certificates: bool,
    use_ratchet_tree_extension: bool,
}

impl Default for ClientOptions {
    fn default() -> Self {
        Self {
            root_ca_certificates: Vec::new(),
            allow_self_signed_certificates: false,
            use_ratchet_tree_extension: true,
        }
    }
}

impl WasmIdentityProvider {
    fn new(options: &ClientOptions) -> Result<Self, JsError> {
        let root_ca_list = options
            .root_ca_certificates
            .iter()
            .cloned()
            .map(DerCertificate::from)
            .collect();

        let mut validator = X509Validator::new(root_ca_list).map_err(js_error)?;
        validator.allow_self_signed(options.allow_self_signed_certificates);

        Ok(Self {
            basic: BasicIdentityProvider::new(),
            x509: X509IdentityProvider::new(
                SubjectIdentityExtractor::new(0, X509Reader::new()),
                validator,
            ),
        })
    }
}

macro_rules! dispatch_credential {
    ($self:expr, $signing_identity:expr, $method:ident ( $($args:expr),* )) => {{
        match $signing_identity.credential.credential_type() {
            CredentialType::BASIC => maybe_await!($self
                .basic
                .$method($signing_identity, $($args),*))
                .map_err(|err| {
                    WasmIdentityProviderError::AnyError(err.into_any_error())
                }),
            CredentialType::X509 => maybe_await!($self
                .x509
                .$method($signing_identity, $($args),*))
                .map_err(|err| {
                    WasmIdentityProviderError::AnyError(err.into_any_error())
                }),
            other => Err(WasmIdentityProviderError::UnsupportedCredentialType(other)),
        }
    }};
}

#[cfg_attr(not(mls_build_async), maybe_async::must_be_sync)]
#[cfg_attr(mls_build_async, maybe_async::must_be_async)]
impl IdentityProvider for WasmIdentityProvider {
    type Error = WasmIdentityProviderError;

    async fn validate_member(
        &self,
        signing_identity: &SigningIdentity,
        timestamp: Option<MlsTime>,
        context: MemberValidationContext<'_>,
    ) -> Result<(), Self::Error> {
        dispatch_credential!(self, signing_identity, validate_member(timestamp, context))
    }

    async fn validate_external_sender(
        &self,
        signing_identity: &SigningIdentity,
        timestamp: Option<MlsTime>,
        extensions: Option<&mls_rs_core::extension::ExtensionList>,
    ) -> Result<(), Self::Error> {
        dispatch_credential!(
            self,
            signing_identity,
            validate_external_sender(timestamp, extensions)
        )
    }

    async fn identity(
        &self,
        signing_identity: &SigningIdentity,
        extensions: &mls_rs_core::extension::ExtensionList,
    ) -> Result<Vec<u8>, Self::Error> {
        dispatch_credential!(self, signing_identity, identity(extensions))
    }

    async fn valid_successor(
        &self,
        predecessor: &SigningIdentity,
        successor: &SigningIdentity,
        extensions: &mls_rs_core::extension::ExtensionList,
    ) -> Result<bool, Self::Error> {
        match predecessor.credential.credential_type() {
            CredentialType::BASIC => {
                maybe_await!(self
                    .basic
                    .valid_successor(predecessor, successor, extensions))
                .map_err(|err| WasmIdentityProviderError::AnyError(err.into_any_error()))
            }
            CredentialType::X509 => {
                maybe_await!(self
                    .x509
                    .valid_successor(predecessor, successor, extensions))
                .map_err(|err| WasmIdentityProviderError::AnyError(err.into_any_error()))
            }
            other => Err(WasmIdentityProviderError::UnsupportedCredentialType(other)),
        }
    }

    fn supported_types(&self) -> Vec<CredentialType> {
        let mut supported = self.basic.supported_types();
        supported.extend(self.x509.supported_types());
        supported
    }
}

#[cfg(target_family = "wasm")]
mod storage;

/// Group-state store used by `WasmMlsConfig`: IndexedDB-backed on
/// wasm, plain in-memory elsewhere.
#[cfg(target_family = "wasm")]
type GroupStore = storage::IdbGroupStateStorage;
#[cfg(not(target_family = "wasm"))]
type GroupStore = InMemoryGroupStateStorage;

/// Key-package store used by `WasmMlsConfig`: IndexedDB-backed on
/// wasm, plain in-memory elsewhere.
#[cfg(target_family = "wasm")]
type KeyPackageStore = storage::IdbKeyPackageStorage;
#[cfg(not(target_family = "wasm"))]
type KeyPackageStore = InMemoryKeyPackageStorage;

/// In-memory (non-persistent) stores for `WasmClient::new`/`newX509`.
fn ephemeral_stores() -> (GroupStore, KeyPackageStore) {
    #[cfg(target_family = "wasm")]
    return (GroupStore::in_memory(), KeyPackageStore::in_memory());
    #[cfg(not(target_family = "wasm"))]
    (
        InMemoryGroupStateStorage::new(),
        InMemoryKeyPackageStorage::new(),
    )
}

type WasmMlsConfig = client_builder::WithIdentityProvider<
    WasmIdentityProvider,
    client_builder::WithCryptoProvider<
        RustCryptoProvider,
        WithGroupStateStorage<
            GroupStore,
            client_builder::WithKeyPackageRepo<
                KeyPackageStore,
                client_builder::WithMlsRules<DefaultMlsRules, client_builder::BaseConfig>,
            >,
        >,
    >,
>;

fn js_error<E: Debug>(err: E) -> JsError {
    JsError::new(&format!("{err:?}"))
}

fn mls_error(err: mls_rs::error::MlsError) -> JsError {
    JsError::new(&format!("{err:?}"))
}

/// A (public, secret) MLS signature keypair.
///
/// `secret_key` is the provider's serialized secret key; keep it
/// private — it is never sent to the network by mls-rs itself.
#[wasm_bindgen]
pub struct WasmSignatureKeypair {
    /// MLS cipher suite this keypair belongs to.
    #[wasm_bindgen(getter_with_clone)]
    pub cipher_suite: WasmCipherSuite,
    public_key: Vec<u8>,
    secret_key: Vec<u8>,
}

#[wasm_bindgen]
impl WasmSignatureKeypair {
    #[wasm_bindgen(getter)]
    pub fn public_key(&self) -> Vec<u8> {
        self.public_key.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn secret_key(&self) -> Vec<u8> {
        self.secret_key.clone()
    }

    /// Construct a keypair from raw key bytes, e.g. a private key
    /// belonging to an X.509 certificate.
    ///
    /// Secret-key encodings: 64-byte keypair encoding for Ed25519,
    /// raw scalar bytes for the NIST curves.
    #[wasm_bindgen(constructor)]
    pub fn new(cipher_suite: WasmCipherSuite, public_key: Vec<u8>, secret_key: Vec<u8>) -> Self {
        Self {
            cipher_suite,
            public_key,
            secret_key,
        }
    }
}

/// Generate a fresh MLS signature keypair for `cipher_suite`.
#[cfg_attr(not(mls_build_async), maybe_async::must_be_sync)]
#[cfg_attr(mls_build_async, maybe_async::must_be_async)]
#[wasm_bindgen]
pub async fn generate_signature_keypair(
    cipher_suite: WasmCipherSuite,
) -> Result<WasmSignatureKeypair, JsError> {
    let provider = RustCryptoProvider::default();
    let suite_provider = provider
        .cipher_suite_provider(cipher_suite.into())
        .ok_or_else(|| JsError::new("unsupported cipher suite"))?;

    let (secret_key, public_key) = suite_provider
        .signature_key_generate()
        .await
        .map_err(|err| JsError::new(&format!("{err:?}")))?;

    Ok(WasmSignatureKeypair {
        cipher_suite,
        public_key: public_key.to_vec(),
        secret_key: secret_key.as_bytes().to_vec(),
    })
}

/// Convert a `js_sys::Array` of `Uint8Array` into `Vec<Vec<u8>>`.
fn byte_arrays(array: &js_sys::Array) -> Vec<Vec<u8>> {
    array
        .iter()
        .map(|value| js_sys::Uint8Array::from(value).to_vec())
        .collect()
}

/// An MLS client able to create key packages and manage groups.
#[wasm_bindgen]
pub struct WasmClient {
    inner: Mutex<mls_rs::Client<WasmMlsConfig>>,
    identity_provider: WasmIdentityProvider,
    signing_identity: mls_rs_core::identity::SigningIdentity,
    /// DER certificate chain when created via `newX509`.
    x509_chain: Option<Vec<Vec<u8>>>,
    /// Persistence handle — `Some` for clients created via
    /// `openPersistent*`.
    #[cfg(target_family = "wasm")]
    storage_backend: Option<std::sync::Arc<storage::IdbBackend>>,
}

fn make_client(
    credential: Credential,
    keypair: &WasmSignatureKeypair,
    options: &ClientOptions,
    group_storage: GroupStore,
    key_package_storage: KeyPackageStore,
) -> Result<mls_rs::Client<WasmMlsConfig>, JsError> {
    let identity_provider = WasmIdentityProvider::new(options)?;
    let signing_identity = SigningIdentity::new(
        credential,
        mls_rs_core::crypto::SignaturePublicKey::from(keypair.public_key.clone()),
    );

    let commit_options = mls_rules::CommitOptions::default()
        .with_ratchet_tree_extension(options.use_ratchet_tree_extension)
        .with_single_welcome_message(true);
    let mls_rules = DefaultMlsRules::new().with_commit_options(commit_options);

    let client = mls_rs::Client::builder()
        .crypto_provider(RustCryptoProvider::default())
        .identity_provider(identity_provider)
        .signing_identity(
            signing_identity,
            mls_rs_core::crypto::SignatureSecretKey::from(keypair.secret_key.clone()),
            keypair.cipher_suite.into(),
        )
        .group_state_storage(group_storage)
        .key_package_repo(key_package_storage)
        .mls_rules(mls_rules)
        .build();

    Ok(client)
}

/// Internal accessor hiding the sync/async mutex split.
impl WasmClient {
    #[cfg(not(mls_build_async))]
    fn client(&self) -> std::sync::MutexGuard<'_, mls_rs::Client<WasmMlsConfig>> {
        self.inner.lock().unwrap()
    }

    #[cfg(mls_build_async)]
    async fn client(&self) -> tokio::sync::MutexGuard<'_, mls_rs::Client<WasmMlsConfig>> {
        self.inner.lock().await
    }
}

#[cfg_attr(not(mls_build_async), maybe_async::must_be_sync)]
#[cfg_attr(mls_build_async, maybe_async::must_be_async)]
#[wasm_bindgen]
impl WasmClient {
    /// Create a client identified by a basic credential (an opaque
    /// application-level identifier).
    ///
    /// State is in-memory only — use [`WasmClient::openPersistent`]
    /// for storage that survives a page reload.
    #[wasm_bindgen(constructor)]
    pub fn new(id: Vec<u8>, keypair: &WasmSignatureKeypair) -> Result<WasmClient, JsError> {
        let credential = mls_rs_core::identity::BasicCredential::new(id).into_credential();
        let options = ClientOptions::default();
        let identity_provider = WasmIdentityProvider::new(&options)?;
        let signing_identity = SigningIdentity::new(
            credential.clone(),
            mls_rs_core::crypto::SignaturePublicKey::from(keypair.public_key.clone()),
        );
        let (group_store, key_package_store) = ephemeral_stores();
        let client = make_client(
            credential,
            keypair,
            &options,
            group_store,
            key_package_store,
        )?;
        Ok(WasmClient {
            inner: Mutex::new(client),
            identity_provider,
            signing_identity,
            x509_chain: None,
            #[cfg(target_family = "wasm")]
            storage_backend: None,
        })
    }

    /// Create a client identified by an X.509 certificate chain.
    ///
    /// `certificate_chain` is an array of DER-encoded certificates,
    /// leaf first. `root_ca_certificates` lists the DER-encoded trust
    /// anchors; when `allow_self_signed_certificates` is set a
    /// single-element self-signed chain is also accepted (testing
    /// only). The leaf public key must match `keypair.public_key`.
    #[wasm_bindgen(js_name = "newX509")]
    pub fn new_x509(
        certificate_chain: &js_sys::Array,
        root_ca_certificates: &js_sys::Array,
        allow_self_signed_certificates: bool,
        keypair: &WasmSignatureKeypair,
    ) -> Result<WasmClient, JsError> {
        let chain_bytes = byte_arrays(certificate_chain);
        let chain = mls_rs_core::identity::CertificateChain::from(chain_bytes.clone());
        let options = ClientOptions {
            root_ca_certificates: byte_arrays(root_ca_certificates),
            allow_self_signed_certificates,
            ..Default::default()
        };

        let identity_provider = WasmIdentityProvider::new(&options)?;
        let leaf_key = mls_rs_identity_x509::X509CredentialValidator::validate_chain(
            &identity_provider.x509.validator,
            &chain,
            None,
        )
        .map_err(js_error)?;

        if leaf_key != mls_rs_core::crypto::SignaturePublicKey::from(keypair.public_key.clone()) {
            return Err(JsError::new(&format!(
                "{:?}",
                X509IdentityError::SignatureKeyMismatch
            )));
        }

        let signing_identity = SigningIdentity::new(
            chain.clone().into_credential(),
            mls_rs_core::crypto::SignaturePublicKey::from(keypair.public_key.clone()),
        );
        let (group_store, key_package_store) = ephemeral_stores();
        let client = make_client(
            chain.into_credential(),
            keypair,
            &options,
            group_store,
            key_package_store,
        )?;
        Ok(WasmClient {
            inner: Mutex::new(client),
            identity_provider,
            signing_identity,
            x509_chain: Some(chain_bytes),
            #[cfg(target_family = "wasm")]
            storage_backend: None,
        })
    }

    /// The application-level identifier of this client's identity
    /// (the basic credential id or the X.509 subject common name).
    #[wasm_bindgen(js_name = "identity")]
    pub async fn identity(&self) -> Result<Vec<u8>, JsError> {
        self.identity_provider
            .identity(&self.signing_identity, &mls_rs::ExtensionList::new())
            .await
            .map_err(|err| js_error(err))
    }

    /// This client's signature public key bytes — needed by peers on
    /// other platforms to reference this member (e.g. for removal).
    #[wasm_bindgen(js_name = "publicKey")]
    pub fn public_key(&self) -> Vec<u8> {
        self.signing_identity.signature_key.to_vec()
    }

    /// The DER certificate chain this client was created with, or
    /// `undefined` for basic-credential clients.
    #[wasm_bindgen(js_name = "x509CertificateChain")]
    pub fn x509_certificate_chain(&self) -> Option<js_sys::Array> {
        self.x509_chain.as_ref().map(|chain| {
            chain
                .iter()
                .map(|c| js_sys::Uint8Array::from(c.as_slice()))
                .collect()
        })
    }

    /// Generate a new key package message (published for others to add
    /// this client to groups).
    #[wasm_bindgen(js_name = "generateKeyPackageMessage")]
    pub async fn generate_key_package_message(&self) -> Result<Vec<u8>, JsError> {
        self.client()
            .await
            .generate_key_package_message(Default::default(), Default::default(), None)
            .await
            .and_then(|message| message.to_bytes().map_err(Into::into))
            .map_err(mls_error)
    }

    /// Create a new group; returns a [`WasmGroup`].
    #[wasm_bindgen(js_name = "createGroup")]
    pub async fn create_group(&self, group_id: Option<Vec<u8>>) -> Result<WasmGroup, JsError> {
        let client = self.client().await;
        let group = match group_id {
            Some(id) => {
                client
                    .create_group_with_id(id, Default::default(), Default::default(), None)
                    .await
            }
            None => {
                client
                    .create_group(Default::default(), Default::default(), None)
                    .await
            }
        }
        .map_err(mls_error)?;

        Ok(WasmGroup {
            inner: Mutex::new(group),
            identity_provider: self.identity_provider.clone(),
        })
    }

    /// Join a group from a welcome message (and optionally a ratchet
    /// tree supplied out of band).
    #[wasm_bindgen(js_name = "joinGroup")]
    pub async fn join_group(
        &self,
        welcome_message: &[u8],
        ratchet_tree: Option<Vec<u8>>,
    ) -> Result<WasmGroup, JsError> {
        let welcome = mls_rs::MlsMessage::from_bytes(welcome_message).map_err(js_error)?;
        let tree = ratchet_tree
            .map(|bytes| mls_rs::group::ExportedTree::from_bytes(&bytes))
            .transpose()
            .map_err(js_error)?;

        let (group, _) = self
            .client()
            .await
            .join_group(tree, &welcome, None)
            .await
            .map_err(mls_error)?;

        Ok(WasmGroup {
            inner: Mutex::new(group),
            identity_provider: self.identity_provider.clone(),
        })
    }

    /// Load a group this client has persisted state for — for
    /// `openPersistent*` clients this survives a page reload; for
    /// in-memory clients it only finds groups created in this session.
    #[wasm_bindgen(js_name = "loadGroup")]
    pub async fn load_group(&self, group_id: Vec<u8>) -> Result<WasmGroup, JsError> {
        let group = self
            .client()
            .await
            .load_group(&group_id)
            .await
            .map_err(mls_error)?;
        Ok(WasmGroup {
            inner: Mutex::new(group),
            identity_provider: self.identity_provider.clone(),
        })
    }
}

/// Persistent-storage API — IndexedDB-backed, always asynchronous
/// regardless of the `mls_build_async` build mode.
#[cfg(target_family = "wasm")]
#[wasm_bindgen]
impl WasmClient {
    /// Open (or create) a persistent client backed by the IndexedDB
    /// database `mls-rs-{name}`.
    ///
    /// `storage_key` is a 32-byte AES-256 key the application
    /// generates once and persists (e.g. derived from a passphrase or
    /// stored in the platform keystore). Every stored value is
    /// AES-256-GCM encrypted; a wrong key fails open.
    ///
    /// Group state, prior-epoch secrets and key-package private keys
    /// all survive page reloads, so a Welcome addressed to a key
    /// package generated before a reload can still be joined.
    #[wasm_bindgen(js_name = "openPersistent")]
    pub async fn open_persistent(
        name: String,
        id: Vec<u8>,
        keypair: &WasmSignatureKeypair,
        storage_key: Vec<u8>,
    ) -> Result<WasmClient, JsError> {
        let (backend, group_store, key_package_store) =
            storage::open_stores(&name, &storage_key).await?;
        let credential = mls_rs_core::identity::BasicCredential::new(id).into_credential();
        let options = ClientOptions::default();
        let identity_provider = WasmIdentityProvider::new(&options)?;
        let signing_identity = SigningIdentity::new(
            credential.clone(),
            mls_rs_core::crypto::SignaturePublicKey::from(keypair.public_key.clone()),
        );
        let client = make_client(
            credential,
            keypair,
            &options,
            group_store,
            key_package_store,
        )?;
        Ok(WasmClient {
            inner: Mutex::new(client),
            identity_provider,
            signing_identity,
            x509_chain: None,
            storage_backend: Some(backend),
        })
    }

    /// [`WasmClient::openPersistent`] with an X.509 certificate-chain
    /// credential — same parameters as [`WasmClient::newX509`] plus
    /// `name` and `storage_key`.
    #[wasm_bindgen(js_name = "openPersistentX509")]
    pub async fn open_persistent_x509(
        name: String,
        certificate_chain: &js_sys::Array,
        root_ca_certificates: &js_sys::Array,
        allow_self_signed_certificates: bool,
        keypair: &WasmSignatureKeypair,
        storage_key: Vec<u8>,
    ) -> Result<WasmClient, JsError> {
        let (backend, group_store, key_package_store) =
            storage::open_stores(&name, &storage_key).await?;

        let chain_bytes = byte_arrays(certificate_chain);
        let chain = mls_rs_core::identity::CertificateChain::from(chain_bytes.clone());
        let options = ClientOptions {
            root_ca_certificates: byte_arrays(root_ca_certificates),
            allow_self_signed_certificates,
            ..Default::default()
        };

        let identity_provider = WasmIdentityProvider::new(&options)?;
        let leaf_key = mls_rs_identity_x509::X509CredentialValidator::validate_chain(
            &identity_provider.x509.validator,
            &chain,
            None,
        )
        .map_err(js_error)?;

        if leaf_key != mls_rs_core::crypto::SignaturePublicKey::from(keypair.public_key.clone()) {
            return Err(JsError::new(&format!(
                "{:?}",
                X509IdentityError::SignatureKeyMismatch
            )));
        }

        let signing_identity = SigningIdentity::new(
            chain.clone().into_credential(),
            mls_rs_core::crypto::SignaturePublicKey::from(keypair.public_key.clone()),
        );
        let client = make_client(
            chain.into_credential(),
            keypair,
            &options,
            group_store,
            key_package_store,
        )?;
        Ok(WasmClient {
            inner: Mutex::new(client),
            identity_provider,
            signing_identity,
            x509_chain: Some(chain_bytes),
            storage_backend: Some(backend),
        })
    }

    /// Await all pending IndexedDB writes and surface the first write
    /// error, if any.
    ///
    /// In sync builds storage writes are committed to IndexedDB in the
    /// background — call this before the page unloads or before
    /// handing ciphertext to the network when the next message must
    /// survive a crash. In `mls_build_async` builds every call already
    /// awaited its write, so this resolves immediately.
    #[wasm_bindgen(js_name = "flushStorage")]
    pub async fn flush_storage(&self) -> Result<(), JsError> {
        match &self.storage_backend {
            Some(backend) => backend.flush().await,
            None => Ok(()),
        }
    }

    /// Close this client's IndexedDB connection, if any. Pending
    /// writes still complete; further storage writes will fail.
    /// `deletePersistentStorage` blocks until every open connection is
    /// closed — call this (or `free()`) on clients you no longer need.
    #[wasm_bindgen(js_name = "close")]
    pub fn close(&self) {
        if let Some(backend) = &self.storage_backend {
            backend.close();
        }
    }

    /// Delete the whole `mls-rs-{name}` IndexedDB database. Browsers
    /// block deletion while any connection to the database is open —
    /// `close()` every client using it first.
    #[wasm_bindgen(js_name = "deletePersistentStorage")]
    pub async fn delete_persistent_storage(name: String) -> Result<(), JsError> {
        storage::delete_database(&name).await
    }
}

#[cfg(target_family = "wasm")]
impl Drop for WasmClient {
    fn drop(&mut self) {
        self.close();
    }
}

/// The result of a group commit: the commit message to fan out plus
/// an optional welcome message for new members.
#[wasm_bindgen]
pub struct WasmCommitOutput {
    commit_message: Vec<u8>,
    welcome_message: Option<Vec<u8>>,
    ratchet_tree: Option<Vec<u8>>,
}

#[wasm_bindgen]
impl WasmCommitOutput {
    #[wasm_bindgen(getter)]
    pub fn commit_message(&self) -> Vec<u8> {
        self.commit_message.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn welcome_message(&self) -> Option<Vec<u8>> {
        self.welcome_message.clone()
    }

    #[wasm_bindgen(getter)]
    pub fn ratchet_tree(&self) -> Option<Vec<u8>> {
        self.ratchet_tree.clone()
    }
}

fn commit_output_of(output: mls_rs::group::CommitOutput) -> Result<WasmCommitOutput, JsError> {
    Ok(WasmCommitOutput {
        commit_message: output.commit_message.to_bytes().map_err(js_error)?,
        welcome_message: output
            .welcome_messages
            .into_iter()
            .next()
            .map(|m| m.to_bytes())
            .transpose()
            .map_err(js_error)?,
        ratchet_tree: output
            .ratchet_tree
            .map(|tree| tree.to_bytes())
            .transpose()
            .map_err(js_error)?,
    })
}

/// What [`WasmGroup::process_incoming_message`] produced.
#[wasm_bindgen]
pub struct WasmReceivedMessage {
    kind: String,
    data: Option<Vec<u8>>,
    sender_index: Option<u32>,
}

#[wasm_bindgen]
impl WasmReceivedMessage {
    /// `"application"`, `"commit"`, `"proposal"`, `"groupInfo"`,
    /// `"welcome"` or `"keyPackage"`.
    #[wasm_bindgen(getter)]
    pub fn kind(&self) -> String {
        self.kind.clone()
    }

    /// Application payload when `kind == "application"`.
    #[wasm_bindgen(getter)]
    pub fn data(&self) -> Option<Vec<u8>> {
        self.data.clone()
    }

    /// Sender's leaf index within the group when known.
    #[wasm_bindgen(getter)]
    pub fn sender_index(&self) -> Option<u32> {
        self.sender_index
    }
}

/// A member of a [`WasmGroup`], as returned by [`WasmGroup::members`].
#[wasm_bindgen]
pub struct WasmMember {
    /// Leaf index — the same index space as
    /// [`WasmReceivedMessage::sender_index`] and the input to
    /// [`WasmGroup::removeMembers`].
    #[wasm_bindgen(getter_with_clone)]
    pub index: u32,
    identity: Vec<u8>,
    public_key: Vec<u8>,
}

#[wasm_bindgen]
impl WasmMember {
    /// Application-level identifier (basic id or X.509 subject CN).
    #[wasm_bindgen(getter)]
    pub fn identity(&self) -> Vec<u8> {
        self.identity.clone()
    }

    /// The member's signature public key bytes.
    #[wasm_bindgen(getter)]
    pub fn public_key(&self) -> Vec<u8> {
        self.public_key.clone()
    }
}

/// An MLS end-to-end encrypted group.
#[wasm_bindgen]
pub struct WasmGroup {
    inner: Mutex<mls_rs::Group<WasmMlsConfig>>,
    identity_provider: WasmIdentityProvider,
}

/// Internal accessor hiding the sync/async mutex split.
impl WasmGroup {
    #[cfg(not(mls_build_async))]
    fn group(&self) -> std::sync::MutexGuard<'_, mls_rs::Group<WasmMlsConfig>> {
        self.inner.lock().unwrap()
    }

    #[cfg(mls_build_async)]
    async fn group(&self) -> tokio::sync::MutexGuard<'_, mls_rs::Group<WasmMlsConfig>> {
        self.inner.lock().await
    }
}

#[cfg_attr(not(mls_build_async), maybe_async::must_be_sync)]
#[cfg_attr(mls_build_async, maybe_async::must_be_async)]
#[wasm_bindgen]
impl WasmGroup {
    /// Add members by key-package messages; returns commit + welcome.
    #[wasm_bindgen(js_name = "addMembers")]
    pub async fn add_members(
        &self,
        key_packages: &js_sys::Array,
    ) -> Result<WasmCommitOutput, JsError> {
        let mut group = self.group().await;
        let mut builder = group.commit_builder();
        for bytes in byte_arrays(key_packages) {
            let key_package = mls_rs::MlsMessage::from_bytes(&bytes).map_err(js_error)?;
            builder = builder.add_member(key_package).map_err(mls_error)?;
        }
        commit_output_of(builder.build().await.map_err(mls_error)?)
    }

    /// Propose adding members (key-package messages). The proposals
    /// are applied by the next `commit` — by this member or another.
    #[wasm_bindgen(js_name = "proposeAddMembers")]
    pub async fn propose_add_members(
        &self,
        key_packages: &js_sys::Array,
    ) -> Result<Vec<js_sys::Uint8Array>, JsError> {
        let mut group = self.group().await;
        let mut out = Vec::new();
        for bytes in byte_arrays(key_packages) {
            let kp = mls_rs::MlsMessage::from_bytes(&bytes).map_err(js_error)?;
            let proposal = group
                .propose_add(kp, Vec::new())
                .await
                .and_then(|m| m.to_bytes().map_err(Into::into))
                .map_err(mls_error)?;
            out.push(js_sys::Uint8Array::from(proposal.as_slice()));
        }
        Ok(out)
    }

    /// Remove members by leaf index (see [`WasmMember::index`] /
    /// [`WasmReceivedMessage::sender_index`]); returns commit output.
    /// The produced commit is wire-compatible with other platforms'
    /// `removeMembers`.
    #[wasm_bindgen(js_name = "removeMembers")]
    pub async fn remove_members(
        &self,
        member_indices: Vec<u32>,
    ) -> Result<WasmCommitOutput, JsError> {
        let mut group = self.group().await;
        let mut builder = group.commit_builder();
        for index in member_indices {
            builder = builder.remove_member(index).map_err(mls_error)?;
        }
        commit_output_of(builder.build().await.map_err(mls_error)?)
    }

    /// Propose removing members by leaf index; applied by the next
    /// `commit`.
    #[wasm_bindgen(js_name = "proposeRemoveMembers")]
    pub async fn propose_remove_members(
        &self,
        member_indices: Vec<u32>,
    ) -> Result<Vec<js_sys::Uint8Array>, JsError> {
        let mut group = self.group().await;
        let mut out = Vec::new();
        for index in member_indices {
            let proposal = group
                .propose_remove(index, Vec::new())
                .await
                .and_then(|m| m.to_bytes().map_err(Into::into))
                .map_err(mls_error)?;
            out.push(js_sys::Uint8Array::from(proposal.as_slice()));
        }
        Ok(out)
    }

    /// List the current group members (index, resolved identity,
    /// signature public key).
    pub async fn members(&self) -> Result<Vec<WasmMember>, JsError> {
        let group = self.group().await;
        let empty = mls_rs::ExtensionList::new();
        let mut members = Vec::new();
        for member in group.roster().members() {
            let identity = maybe_await!(self
                .identity_provider
                .identity(&member.signing_identity, &empty))
            .map_err(js_error)?;
            members.push(WasmMember {
                index: member.index,
                identity,
                public_key: member.signing_identity.signature_key.to_vec(),
            });
        }
        Ok(members)
    }

    /// Commit pending proposals (an empty commit refreshes the
    /// sender's key material).
    pub async fn commit(&self) -> Result<WasmCommitOutput, JsError> {
        let mut group = self.group().await;
        commit_output_of(group.commit(Vec::new()).await.map_err(mls_error)?)
    }

    /// Encrypt an application message for the group.
    #[wasm_bindgen(js_name = "encryptApplicationMessage")]
    pub async fn encrypt_application_message(&self, message: &[u8]) -> Result<Vec<u8>, JsError> {
        self.group()
            .await
            .encrypt_application_message(message, Vec::new())
            .await
            .and_then(|m| m.to_bytes().map_err(Into::into))
            .map_err(mls_error)
    }

    /// Process an inbound MLS message.
    #[wasm_bindgen(js_name = "processIncomingMessage")]
    pub async fn process_incoming_message(
        &self,
        message: &[u8],
    ) -> Result<WasmReceivedMessage, JsError> {
        let mls_message = mls_rs::MlsMessage::from_bytes(message).map_err(js_error)?;
        let mut group = self.group().await;
        match group
            .process_incoming_message(mls_message)
            .await
            .map_err(mls_error)?
        {
            mls_rs::group::ReceivedMessage::ApplicationMessage(m) => Ok(WasmReceivedMessage {
                kind: "application".into(),
                data: Some(m.data().to_vec()),
                sender_index: Some(m.sender_index),
            }),
            mls_rs::group::ReceivedMessage::Commit(_) => Ok(WasmReceivedMessage {
                kind: "commit".into(),
                data: None,
                sender_index: None,
            }),
            mls_rs::group::ReceivedMessage::Proposal(_) => Ok(WasmReceivedMessage {
                kind: "proposal".into(),
                data: None,
                sender_index: None,
            }),
            mls_rs::group::ReceivedMessage::GroupInfo(_) => Ok(WasmReceivedMessage {
                kind: "groupInfo".into(),
                data: None,
                sender_index: None,
            }),
            mls_rs::group::ReceivedMessage::Welcome => Ok(WasmReceivedMessage {
                kind: "welcome".into(),
                data: None,
                sender_index: None,
            }),
            mls_rs::group::ReceivedMessage::KeyPackage(_) => Ok(WasmReceivedMessage {
                kind: "keyPackage".into(),
                data: None,
                sender_index: None,
            }),
        }
    }

    /// Persist the group state via the storage provider.
    #[wasm_bindgen(js_name = "writeToStorage")]
    pub async fn write_to_storage(&self) -> Result<(), JsError> {
        self.group()
            .await
            .write_to_storage()
            .await
            .map_err(mls_error)
    }

    /// Export the current ratchet tree for out-of-band transfer.
    #[wasm_bindgen(js_name = "exportTree")]
    pub async fn export_tree(&self) -> Result<Vec<u8>, JsError> {
        self.group()
            .await
            .export_tree()
            .to_bytes()
            .map_err(js_error)
    }
}
