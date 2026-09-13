# Cipher suites

An MLS cipher suite fixes the KEM, AEAD, hash and signature algorithm
used by a group. The suite is chosen **per signing keypair** — a client's
suite determines which algorithms its key packages advertise.

## The `CipherSuite` enum

{{#tabs }}
{{#tab name="Rust" }}

`mls_rs::CipherSuite` — constants, not an enum:

```rust
use mls_rs::CipherSuite;

let suite = CipherSuite::P521_AES256;      // suite 5
// CURVE25519_AES128  (1)
// P256_AES128        (2)
// CURVE25519_CHACHA  (3)
// P521_AES256        (5)
// P384_AES256        (7)
```

{{#endtab }}
{{#tab name="Kotlin" }}

`uniffi.mls_rs_uniffi.CipherSuite` — enum:

```kotlin
import uniffi.mls_rs_uniffi.CipherSuite

val suite = CipherSuite.P521_AES256
// CURVE25519_AES128, P256_AES128, CURVE25519_CHA_CHA,
// P521_AES256, P384_AES256
```

{{#endtab }}
{{#tab name="Swift" }}

`mls_rs_uniffi.CipherSuite` — enum:

```swift
let suite: CipherSuite = .p521Aes256
// .curve25519Aes128, .p256Aes128, .curve25519ChaCha,
// .p521Aes256, .p384Aes256
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

`WasmCipherSuite` — enum with the RFC numeric values:

```js
import { WasmCipherSuite } from "./mls_rs_wasm.js";

const suite = WasmCipherSuite.P521Aes256;   // === 5
// Curve25519Aes128 = 1, P256Aes128 = 2, Curve25519ChaCha = 3,
// P521Aes256 = 5, P384Aes256 = 7
```

{{#endtab }}
{{#endtabs }}

## Choosing a suite

| Suite | When to pick it |
|-------|-----------------|
| `Curve25519Aes128` (1) | default choice; fastest, Ed25519 signatures |
| `Curve25519ChaCha` (3) | best on devices without AES hardware |
| `P256Aes128` (2) | needed when credentials are P-256 certs |
| `P384Aes256` (7) | 192-bit security level, common enterprise/CA PKI |
| `P521Aes256` (5) | highest classic security level, P-521 certs |

The KEM and signature algorithms of a suite are coupled: e.g. suite 5
clients need a P-521 signature keypair *and* (for X.509 credentials) a
certificate whose SPKI is P-521. See
[Credentials & signature keys](credentials.md).

All members of a group must support the group's cipher suite — mls-rs
rejects key packages that don't.
