# Generating signature keys

Every client needs a `SignatureKeypair` for its chosen cipher suite.
Generate a fresh one, or import raw bytes when the key already exists
(e.g. inside a certificate).

## `generate_signature_keypair`

| Platform | Signature |
|----------|-----------|
| Rust | `cipher_suite_provider(suite).signature_key_generate() -> (secret, public)` |
| Kotlin | `generateSignatureKeypair(suite: CipherSuite): SignatureKeypair` |
| Swift | `generateSignatureKeypair(cipherSuite: CipherSuite) throws -> SignatureKeypair` |
| WASM | `generate_signature_keypair(suite: WasmCipherSuite): WasmSignatureKeypair` |

{{#tabs }}
{{#tab name="Rust" }}

```rust
let provider = RustCryptoProvider::default();
let csp = provider.cipher_suite_provider(CipherSuite::P521_AES256)
    .ok_or(MlsError::UnsupportedCipherSuite(CipherSuite::P521_AES256))?;
let (secret, public) = csp.signature_key_generate().await?;
// secret: SignatureSecretKey, public: SignaturePublicKey
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
val keypair = generateSignatureKeypair(CipherSuite.P521_AES256)
keypair.cipherSuite   // echoes the suite
keypair.publicKey     // SignaturePublicKey(bytes)
keypair.secretKey     // SignatureSecretKey(bytes) — keep private
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
let keypair = try generateSignatureKeypair(cipherSuite: .p521Aes256)
keypair.cipherSuite
keypair.publicKey.bytes   // Data
keypair.secretKey.bytes   // Data — keep private
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const keypair = generate_signature_keypair(WasmCipherSuite.P521Aes256);
keypair.cipher_suite;    // echoes the suite
keypair.public_key;      // Uint8Array
keypair.secret_key;      // Uint8Array — keep private
```

{{#endtab }}
{{#endtabs }}

## Importing an existing keypair

{{#tabs }}
{{#tab name="Rust" }}

```rust
let secret = SignatureSecretKey::new(secret_bytes);
let public = SignaturePublicKey::new(public_bytes);
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
val keypair = SignatureKeypair(
    cipherSuite = CipherSuite.P521_AES256,
    publicKey = SignaturePublicKey(publicBytes),
    secretKey = SignatureSecretKey(secretBytes),
)
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
let keypair = SignatureKeypair(
    cipherSuite: .p521Aes256,
    publicKey: SignaturePublicKey(bytes: publicBytes),
    secretKey: SignatureSecretKey(bytes: secretBytes))
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const keypair = new WasmSignatureKeypair(
    WasmCipherSuite.P521Aes256, publicBytes, secretBytes);
```

{{#endtab }}
{{#endtabs }}

Byte encodings per suite are listed in
[Credentials & signature keys](../concepts/credentials.md#raw-key-encodings).

## Errors

* `UnsupportedCipherSuite` — the suite isn't implemented by the active
  backend (all five are on RustCrypto).
* Crypto-provider errors if keygen itself fails (RNG, malformed import
  bytes).
