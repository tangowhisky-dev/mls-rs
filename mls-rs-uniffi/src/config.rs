use std::fmt::Debug;
use std::sync::Arc;

use mls_rs::{
    client_builder::{self, WithGroupStateStorage},
    identity::basic,
    storage_provider::in_memory::{InMemoryGroupStateStorage, InMemoryKeyPackageStorage},
};
use mls_rs_core::error::IntoAnyError;
use zeroize::Zeroizing;

use self::group_state::{GroupStateStorage, GroupStateStorageAdapter};
use self::key_package::{ClientKeyPackageStorage, KeyPackageStorage, KeyPackageStorageAdapter};
use crate::Error;

pub mod group_state;
pub mod key_package;

#[cfg(feature = "rustcrypto")]
pub(crate) use mls_rs_crypto_rustcrypto::RustCryptoProvider as UniFFICryptoProvider;

#[cfg(all(feature = "openssl", not(feature = "rustcrypto")))]
pub(crate) use mls_rs_crypto_openssl::OpensslCryptoProvider as UniFFICryptoProvider;

#[cfg(feature = "rustcrypto")]
pub(crate) use mls_rs_crypto_rustcrypto::x509::{
    X509Reader as UniFFIX509Reader, X509Validator as UniFFIX509Validator,
};

#[cfg(all(feature = "openssl", not(feature = "rustcrypto")))]
pub(crate) use mls_rs_crypto_openssl::x509::{
    X509Reader as UniFFIX509Reader, X509Validator as UniFFIX509Validator,
};

/// Identity provider used by [`Client`](crate::Client).
///
/// It accepts [`BasicCredential`](mls_rs_core::identity::BasicCredential)
/// credentials unconditionally (mirroring `BasicIdentityProvider`) and,
/// additionally, X.509 certificate credentials which are validated against
/// the configured root CA list by the crypto backend's X.509 validator.
#[derive(Clone, Debug)]
pub struct UniFFIIdentityProvider {
    basic: basic::BasicIdentityProvider,
    x509: mls_rs_identity_x509::X509IdentityProvider<
        mls_rs_identity_x509::SubjectIdentityExtractor<UniFFIX509Reader>,
        UniFFIX509Validator,
    >,
}

/// Error produced by [`UniFFIIdentityProvider`].
#[derive(Debug, thiserror::Error)]
pub enum UniFFIIdentityProviderError {
    #[error(transparent)]
    AnyError(#[from] mls_rs_core::error::AnyError),
    #[error("unsupported credential type: {0:?}")]
    UnsupportedCredentialType(mls_rs_core::identity::CredentialType),
    #[allow(dead_code)] // constructed only by the `openssl` backend
    #[error("invalid configuration: {0}")]
    InvalidConfig(String),
}

impl mls_rs_core::error::IntoAnyError for UniFFIIdentityProviderError {
    fn into_dyn_error(self) -> Result<Box<dyn std::error::Error + Send + Sync>, Self> {
        Ok(self.into())
    }
}

impl UniFFIIdentityProvider {
    pub(crate) fn new(config: &ClientConfig) -> Result<Self, crate::Error> {
        let root_ca_list = config
            .root_ca_certificates
            .iter()
            .map(|der| mls_rs_identity_x509::DerCertificate::from(der.clone()))
            .collect();

        #[allow(unused_mut)] // `mut` only needed by the `rustcrypto` backend
        let mut validator =
            UniFFIX509Validator::new(root_ca_list).map_err(|err| crate::Error::AnyError {
                inner: err.into_any_error(),
            })?;

        #[cfg(feature = "rustcrypto")]
        validator.allow_self_signed(config.allow_self_signed_certificates);

        #[cfg(all(feature = "openssl", not(feature = "rustcrypto")))]
        if config.allow_self_signed_certificates {
            return Err(crate::Error::AnyError {
                inner: UniFFIIdentityProviderError::InvalidConfig(
                    "self-signed X.509 certificates are only supported by the rustcrypto backend"
                        .to_string(),
                )
                .into_any_error(),
            });
        }

        let identity_extractor =
            mls_rs_identity_x509::SubjectIdentityExtractor::new(0, UniFFIX509Reader::new());

        Ok(Self {
            basic: basic::BasicIdentityProvider::new(),
            x509: mls_rs_identity_x509::X509IdentityProvider::new(identity_extractor, validator),
        })
    }

    /// Validate an X.509 certificate chain and return the leaf signing key.
    ///
    /// Used to sanity-check a certificate chain when constructing an
    /// X.509-backed client.
    pub(crate) fn validate_x509_chain(
        &self,
        chain: &mls_rs_core::identity::CertificateChain,
    ) -> Result<mls_rs_core::crypto::SignaturePublicKey, crate::Error> {
        mls_rs_identity_x509::X509CredentialValidator::validate_chain(
            &self.x509.validator,
            chain,
            None,
        )
        .map_err(|err| crate::Error::AnyError {
            inner: err.into_any_error(),
        })
    }
}

#[cfg_attr(not(mls_build_async), maybe_async::must_be_sync)]
#[cfg_attr(mls_build_async, maybe_async::must_be_async)]
impl mls_rs_core::identity::IdentityProvider for UniFFIIdentityProvider {
    type Error = UniFFIIdentityProviderError;

    async fn validate_member(
        &self,
        signing_identity: &mls_rs_core::identity::SigningIdentity,
        timestamp: Option<mls_rs_core::time::MlsTime>,
        context: mls_rs_core::identity::MemberValidationContext<'_>,
    ) -> Result<(), Self::Error> {
        use mls_rs_core::identity::CredentialType;

        match signing_identity.credential.credential_type() {
            CredentialType::BASIC => self
                .basic
                .validate_member(signing_identity, timestamp, context)
                .await
                .map_err(|err| UniFFIIdentityProviderError::AnyError(err.into_any_error())),
            CredentialType::X509 => self
                .x509
                .validate_member(signing_identity, timestamp, context)
                .await
                .map_err(|err| UniFFIIdentityProviderError::AnyError(err.into_any_error())),
            other => Err(UniFFIIdentityProviderError::UnsupportedCredentialType(
                other,
            )),
        }
    }

    async fn validate_external_sender(
        &self,
        signing_identity: &mls_rs_core::identity::SigningIdentity,
        timestamp: Option<mls_rs_core::time::MlsTime>,
        extensions: Option<&mls_rs_core::extension::ExtensionList>,
    ) -> Result<(), Self::Error> {
        use mls_rs_core::identity::CredentialType;

        match signing_identity.credential.credential_type() {
            CredentialType::BASIC => self
                .basic
                .validate_external_sender(signing_identity, timestamp, extensions)
                .await
                .map_err(|err| UniFFIIdentityProviderError::AnyError(err.into_any_error())),
            CredentialType::X509 => self
                .x509
                .validate_external_sender(signing_identity, timestamp, extensions)
                .await
                .map_err(|err| UniFFIIdentityProviderError::AnyError(err.into_any_error())),
            other => Err(UniFFIIdentityProviderError::UnsupportedCredentialType(
                other,
            )),
        }
    }

    async fn identity(
        &self,
        signing_identity: &mls_rs_core::identity::SigningIdentity,
        extensions: &mls_rs_core::extension::ExtensionList,
    ) -> Result<Vec<u8>, Self::Error> {
        use mls_rs_core::identity::CredentialType;

        match signing_identity.credential.credential_type() {
            CredentialType::BASIC => self
                .basic
                .identity(signing_identity, extensions)
                .await
                .map_err(|err| UniFFIIdentityProviderError::AnyError(err.into_any_error())),
            CredentialType::X509 => self
                .x509
                .identity(signing_identity, extensions)
                .await
                .map_err(|err| UniFFIIdentityProviderError::AnyError(err.into_any_error())),
            other => Err(UniFFIIdentityProviderError::UnsupportedCredentialType(
                other,
            )),
        }
    }

    async fn valid_successor(
        &self,
        predecessor: &mls_rs_core::identity::SigningIdentity,
        successor: &mls_rs_core::identity::SigningIdentity,
        extensions: &mls_rs_core::extension::ExtensionList,
    ) -> Result<bool, Self::Error> {
        use mls_rs_core::identity::CredentialType;

        match predecessor.credential.credential_type() {
            CredentialType::BASIC => self
                .basic
                .valid_successor(predecessor, successor, extensions)
                .await
                .map_err(|err| UniFFIIdentityProviderError::AnyError(err.into_any_error())),
            CredentialType::X509 => self
                .x509
                .valid_successor(predecessor, successor, extensions)
                .await
                .map_err(|err| UniFFIIdentityProviderError::AnyError(err.into_any_error())),
            other => Err(UniFFIIdentityProviderError::UnsupportedCredentialType(
                other,
            )),
        }
    }

    fn supported_types(&self) -> Vec<mls_rs_core::identity::CredentialType> {
        let mut supported = self.basic.supported_types();
        supported.extend(self.x509.supported_types());
        supported
    }
}

pub type UniFFIConfig = client_builder::WithIdentityProvider<
    UniFFIIdentityProvider,
    client_builder::WithCryptoProvider<
        UniFFICryptoProvider,
        client_builder::WithKeyPackageRepo<
            ClientKeyPackageStorage,
            WithGroupStateStorage<ClientGroupStorage, client_builder::BaseConfig>,
        >,
    >,
>;

#[derive(Debug, Clone, uniffi::Record)]
pub struct ClientConfig {
    pub group_state_storage: Arc<dyn GroupStateStorage>,
    /// Persistent storage for key package init secrets. Without it,
    /// welcomes addressed to key packages generated before an app
    /// restart can no longer be joined.
    pub key_package_storage: Arc<dyn KeyPackageStorage>,
    /// Use the ratchet tree extension. If this is false, then you
    /// must supply `ratchet_tree` out of band to clients.
    pub use_ratchet_tree_extension: bool,
    /// DER-encoded root CA certificates used to validate the X.509
    /// certificate chains of other group members.
    pub root_ca_certificates: Vec<Vec<u8>>,
    /// Accept self-signed X.509 certificate chains.
    ///
    /// # Warning
    ///
    /// This is only intended for testing. Do not enable it in
    /// production.
    pub allow_self_signed_certificates: bool,
}

impl Default for ClientConfig {
    fn default() -> Self {
        Self {
            group_state_storage: Arc::new(GroupStateStorageAdapter::new(
                InMemoryGroupStateStorage::new(),
            )),
            key_package_storage: Arc::new(KeyPackageStorageAdapter::new(
                InMemoryKeyPackageStorage::new(),
            )),
            use_ratchet_tree_extension: true,
            root_ca_certificates: Vec::new(),
            allow_self_signed_certificates: false,
        }
    }
}

// TODO(mgeisler): turn into an associated function when UniFFI
// supports them: https://github.com/mozilla/uniffi-rs/issues/1074.
/// Create a client config with an in-memory group state storage.
#[uniffi::export]
pub fn client_config_default() -> ClientConfig {
    ClientConfig::default()
}

#[derive(Debug, Clone)]
pub struct ClientGroupStorage(Arc<dyn GroupStateStorage>);

impl From<Arc<dyn GroupStateStorage>> for ClientGroupStorage {
    fn from(value: Arc<dyn GroupStateStorage>) -> Self {
        Self(value)
    }
}

#[cfg_attr(not(mls_build_async), maybe_async::must_be_sync)]
#[cfg_attr(mls_build_async, maybe_async::must_be_async)]
impl mls_rs_core::group::GroupStateStorage for ClientGroupStorage {
    type Error = Error;

    async fn state(&self, group_id: &[u8]) -> Result<Option<Zeroizing<Vec<u8>>>, Self::Error> {
        let data = self.0.state(group_id.to_vec()).await?;
        Ok(data.map(Into::into))
    }

    async fn epoch(
        &self,
        group_id: &[u8],
        epoch_id: u64,
    ) -> Result<Option<Zeroizing<Vec<u8>>>, Self::Error> {
        let data = self.0.epoch(group_id.to_vec(), epoch_id).await?;
        Ok(data.map(Into::into))
    }

    async fn write(
        &mut self,
        state: mls_rs_core::group::GroupState,
        inserts: Vec<mls_rs_core::group::EpochRecord>,
        updates: Vec<mls_rs_core::group::EpochRecord>,
    ) -> Result<(), Self::Error> {
        self.0
            .write(
                state.id,
                state.data.to_vec(),
                inserts.into_iter().map(Into::into).collect(),
                updates.into_iter().map(Into::into).collect(),
            )
            .await
    }

    async fn max_epoch_id(&self, group_id: &[u8]) -> Result<Option<u64>, Self::Error> {
        self.0.max_epoch_id(group_id.to_vec()).await
    }
}
