# Creating clients

A `Client` binds a signing identity to local state (storage, crypto,
identity rules). It owns no groups itself — it creates and joins them.
Create **one client per identity** per device.

## `Client` — basic credential

| Platform | Constructor |
|----------|-------------|
| Rust | `Client::builder()…build()` |
| Kotlin | `Client(id: ByteArray, signatureKeypair, clientConfig)` |
| Swift | `Client(id: Data, signatureKeypair, clientConfig) throws` |
| WASM | `new WasmClient(id, keypair)` or `await WasmClient.openPersistent(name, id, keypair, storageKey)` |

`id` is your application-level identifier — becomes the basic
credential and the MLS identity other members see.

{{#tabs }}
{{#tab name="Rust" }}

```rust
let credential = BasicCredential::new(b"alice".to_vec()).into_credential();
let identity = SigningIdentity::new(credential, public_key);

let alice = Client::builder()
    .crypto_provider(RustCryptoProvider::default())
    .identity_provider(BasicIdentityProvider::new())
    .signing_identity(identity, secret_key, CipherSuite::P521_AES256)
    .group_state_storage(InMemoryGroupStateStorage::new())
    .mls_rules(mls_rules)
    .build();
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
val alice = Client(
    id = "alice".toByteArray(),
    signatureKeypair = keypair,
    clientConfig = clientConfigDefault(),
)
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
let alice = try Client(
    id: Data("alice".utf8),
    signatureKeypair: keypair,
    clientConfig: clientConfigDefault())
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const alice = new WasmClient(
    new TextEncoder().encode("alice"), keypair);

// or, for IndexedDB-backed persistent state:
const alice2 = await WasmClient.openPersistent(
    "device-1",                        // database `mls-rs-device-1`
    new TextEncoder().encode("alice"),
    keypair,
    storageKey);                       // 32-byte app-managed AES-256 key
```

{{#endtab }}
{{#endtabs }}

`openPersistent` keeps MLS state across page reloads — see
[Persistence](persistence.md). `storageKey` never leaves your app;
a wrong key fails open with a decryption error.

## `Client` — X.509 credential

| Platform | Constructor |
|----------|-------------|
| Kotlin | `Client.newWithX509(certificateChain: List<ByteArray>, signatureKeypair, clientConfig)` |
| Swift | `Client.newWithX509(certificateChain: [Data], signatureKeypair, clientConfig) throws` |
| WASM | `WasmClient.newX509(chain, rootCas, allowSelfSigned, keypair)` or `await WasmClient.openPersistentX509(name, chain, rootCas, allowSelfSigned, keypair, storageKey)` |

Parameters:

* `certificateChain` — DER certs, **leaf first**, then intermediates.
* `signatureKeypair` — must match the leaf cert's public key
  (`SignatureKeyMismatch` otherwise).
* `clientConfig` — set `rootCaCertificates` to your trust anchors.
* WASM only: `rootCaCertificates` and `allowSelfSigned` are direct
  parameters instead of a config object.

{{#tabs }}
{{#tab name="Rust" }}

```rust
let chain = CertificateChain::from(vec![leaf_der, intermediate_der]);
let identity = SigningIdentity::new(chain.into_credential(), public_key);
// identity_provider: X509IdentityProvider::new(
//     SubjectIdentityExtractor::new(0, X509Reader::new()),
//     validator_with_root_cas)
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
val config = clientConfigDefault().copy(
    rootCaCertificates = listOf(rootCaDer))
val alice = Client.newWithX509(
    certificateChain = listOf(leafDer, intermediateDer),
    signatureKeypair = keypair,
    clientConfig = config)
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
var config = clientConfigDefault()
config.rootCaCertificates = [rootCaDer]
let alice = try Client.newWithX509(
    certificateChain: [leafDer, intermediateDer],
    signatureKeypair: keypair, clientConfig: config)
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const alice = WasmClient.newX509(
    [leafDer, intermediateDer],   // Uint8Array[]
    [rootCaDer],                  // trust anchors
    false,                        // allowSelfSigned (tests only)
    keypair);
```

{{#endtab }}
{{#endtabs }}

## Other `Client` methods

| Method | Returns | Purpose |
|--------|---------|---------|
| `generateKeyPackageMessage()` | `Message` / `Uint8Array` | publishable key package — see [Key packages](key_packages.md) |
| `createGroup(groupId?)` | `Group` | new group — see [Creating groups](create_group.md) |
| `joinGroup(tree?, welcome)` | `JoinInfo` / `WasmGroup` | join via welcome — see [Joining groups](join_group.md) |
| `loadGroup(groupId)` | `Group` | reload persisted group — see [Persistence](persistence.md) |
| `signingIdentity()` | `SigningIdentity` | this client's public identity (not on WASM) |
