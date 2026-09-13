# Client configuration

`ClientConfig` controls storage, tree transfer and X.509 trust for every
client you create.

{{#tabs }}
{{#tab name="Rust" }}

Rust doesn't use `ClientConfig` — you assemble the equivalent with the
builder (storage provider, identity provider, mls rules):

```rust
let client = mls_rs::Client::builder()
    .crypto_provider(RustCryptoProvider::default())
    .identity_provider(provider)                // basic, X.509, or custom
    .signing_identity(identity, secret, suite)
    .group_state_storage(InMemoryGroupStateStorage::new()) // or SQLite…
    .mls_rules(DefaultMlsRules::new().with_commit_options(
        CommitOptions::default()
            .with_ratchet_tree_extension(true)
            .with_single_welcome_message(true)))
    .build();
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
val config = clientConfigDefault().copy(
    useRatchetTreeExtension = true,
    rootCaCertificates = listOf(rootCaDer),
    allowSelfSignedCertificates = false,   // tests only when true
    groupStateStorage = myStorage,          // your GroupStateStorage impl
)
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
var config = clientConfigDefault()
config.useRatchetTreeExtension = true
config.rootCaCertificates = [rootCaDer]
config.allowSelfSignedCertificates = false   // tests only
config.groupStateStorage = MyStorage()       // your GroupStateStorage impl
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

There is no `ClientConfig` object — options are parameters on the
constructor:

```js
// basic:   new WasmClient(idBytes, keypair)                 — defaults
// x509:    WasmClient.newX509(chain, rootCas, allowSelfSigned, keypair)
```

Storage is in-memory with `new`/`newX509`; `openPersistent`/
`openPersistentX509` give IndexedDB-backed encrypted persistence (see
[Persistence](../api/persistence.md)). The ratchet-tree extension is
always on.

{{#endtab }}
{{#endtabs }}

## Fields

| Field | Type | Default | Meaning |
|-------|------|---------|---------|
| `groupStateStorage` | `GroupStateStorage` impl | in-memory | where group state + epoch secrets are persisted — see [Persistence](../api/persistence.md) |
| `useRatchetTreeExtension` | bool | `true` | attach the ratchet tree to Welcome messages; when `false`, new members need `exportTree()` out of band |
| `rootCaCertificates` | `List<Data>` / `[Data]` | `[]` | DER-encoded trust anchors for X.509 member validation |
| `allowSelfSignedCertificates` | bool | `false` | accept single-cert self-signed chains — **testing only**, bypasses CA trust |

## Identity provider dispatch

The UniFFI client auto-dispatches on the credential inside each
incoming key package / leaf:

* `BASIC` → accepted unconditionally (`BasicIdentityProvider`)
* `X509` → validated against `rootCaCertificates` by the RustCrypto
  validator (`X509IdentityProvider` + `SubjectIdentityExtractor`)
* anything else → `UnsupportedCredentialType` error

So one `Client` can live in groups mixing basic and X.509 members.
