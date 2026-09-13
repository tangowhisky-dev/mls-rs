# Key packages

A **key package** is a member's "business card": it advertises the
credential, signature public key, HPKE keys, supported cipher suites and
a lifetime. Other members consume key packages to add the client to a
group — the owner doesn't need to be online.

## `generate_key_package_message`

| Platform | Signature | Returns |
|----------|-----------|---------|
| Rust | `client.generate_key_package_message(props, exts, None)` | `MlsMessage` |
| Kotlin | `client.generateKeyPackageMessage()` | `Message` |
| Swift | `client.generateKeyPackageMessage() throws` | `Message` |
| WASM | `client.generateKeyPackageMessage()` | `Uint8Array` |

{{#tabs }}
{{#tab name="Rust" }}

```rust
let key_package: MlsMessage = bob
    .generate_key_package_message(Default::default(), Default::default(), None)
    .await?;
let bytes = key_package.to_bytes()?;   // publish these bytes
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
val keyPackage: Message = bob.generateKeyPackageMessage()
val bytes: ByteArray = keyPackage.toBytes()   // publish these bytes
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
let keyPackage: Message = try bob.generateKeyPackageMessage()
let bytes: Data = try keyPackage.toBytes()    // publish these bytes
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const keyPackage: Uint8Array = bob.generateKeyPackageMessage();
// publish/upload the bytes
```

{{#endtab }}
{{#endtabs }}

## Usage notes

* **Publish, don't share secrets.** Key packages contain only public
  material — safe to host on an untrusted directory server.
* **They expire.** Each carries a `not_before`/`not_after` lifetime;
  mls-rs rejects expired packages. Regenerate periodically and on app
  start if the previous one may be stale.
* **One-shot by default.** With `singleWelcomeMessage` enabled (the
  binding default), a key package is consumed by one join. Clients that
  join many groups should upload several.
* **Init keys stay in memory.** The client remembers each generated
  package's HPKE init private key so `joinGroup` can decrypt the
  matching welcome — the same client instance must generate and join
  (see [joining groups](join_group.md#the-key-package-storage-caveat)).
* **Credential inside.** A basic credential shows the raw `id`; an
  X.509 credential carries the whole chain — peers validate it against
  their `rootCaCertificates` before adding.
* **Receiving one**: feeding a key-package message into
  `processIncomingMessage` yields `ReceivedMessage.KeyPackage` —
  validated but not added.
