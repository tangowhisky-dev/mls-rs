# Introduction

**mls-rs** is a Rust implementation of the Messaging Layer Security
protocol ([RFC 9420](https://www.rfc-editor.org/rfc/rfc9420.html)), the
IETF standard for continuous, asynchronous end-to-end encrypted group
messaging.

This book documents how to **use** this checkout of mls-rs — including
the pure-Rust **RustCrypto** crypto backend — from **Rust, Kotlin/Java,
Swift and WebAssembly** applications. One library, one API shape, five
cipher suites, every major platform.

## What is MLS?

MLS lets a group of clients establish shared encryption state and
evolve it as members join and leave. Properties your app gets for free:

* **Asynchronous** — members are added using pre-published *key
  packages*; nobody needs to be online at the same time.
* **Forward secrecy** — old traffic stays safe after key compromise.
* **Post-compromise security** — members heal their key material via
  regular *commits*.
* **Transport agnostic** — mls-rs produces and consumes opaque byte
  arrays (`MlsMessage`s); your delivery service carries them.

## Crypto providers

mls-rs delegates all primitives to a pluggable `CryptoProvider`. This
repository defaults to **RustCrypto** — audited, pure-Rust crates
(`p256`, `p384`, `p521`, `x25519-dalek`, `ed25519-dalek`, `aes-gcm`,
`chacha20poly1305`, `sha2`, `hkdf`, `x509-cert`, …) — which compiles
everywhere including iOS, Android and `wasm32-unknown-unknown`.
OpenSSL/AWS-LC providers remain available as opt-in alternatives on
platforms that have them.

## Supported cipher suites (RustCrypto backend)

| Suite | MLS name | KEM | AEAD | Signatures | Hash |
|-------|----------|-----|------|------------|------|
| 1 | `MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519` | X25519 | AES-128-GCM | Ed25519 | SHA-256 |
| 2 | `MLS_128_DHKEMP256_AES128GCM_SHA256_P256` | P-256 | AES-128-GCM | ECDSA | SHA-256 |
| 3 | `MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519` | X25519 | ChaCha20-Poly1305 | Ed25519 | SHA-256 |
| 5 | `MLS_256_DHKEMP521_AES256GCM_SHA512_P521` | P-521 | AES-256-GCM | ECDSA | SHA-512 |
| 7 | `MLS_256_DHKEMP384_AES256GCM_SHA384_P384` | P-384 | AES-256-GCM | ECDSA | SHA-384 |

> **Note on numbering:** this repository follows the RFC 9420 numeric
> assignment — suite **5** is the P-521 suite and suite **7** is the
> P-384 suite. Suites 4 and 6 are not supported.

## Supported platforms

| Platform | Path | Validated by |
|----------|------|--------------|
| Rust native (macOS/Linux/…) | crates directly | `platform_testbeds/rust-harness` |
| Android | UniFFI + Kotlin bindings, `.so` per ABI | instrumented tests on emulator |
| iOS | XCFramework + Swift bindings | XCTest on simulator |
| macOS | same XCFramework (macOS slice) | Swift CLI harness |
| Web / Node | wasm-bindgen package | Node + headless Chrome e2e |

## How this book is organized

* **User manual** — prerequisites, installation on each platform,
  verifying your build, and where the conformance test vectors live.
* **Concepts** — cipher suites, credentials, client configuration and
  the message/transport model.
* **API by functionality** — every exposed function, grouped like the
  OpenMLS book, each page showing **Rust / Kotlin / Swift / Web** tabs
  side by side.
* **Appendices** — feature flags and per-platform limitations.

## What your app still owns

mls-rs does not provide:

* **A delivery service** — you route key packages, welcomes, commits
  and ciphertexts between clients yourself.
* **Durable storage by default** — the bindings use in-memory state
  unless you implement `GroupStateStorage` (UniFFI), use the SQLite
  provider (Rust), or open the WASM client via `openPersistent`
  (IndexedDB, AES-256-GCM-encrypted values).
* **User authentication** — MLS *credentials* bind a public key to an
  identifier; how you issue X.509 certificates or map basic IDs is
  your application's job.

## Security notice

mls-rs is validated for RFC 9420 conformance (see
[Test vectors](manual/test_vectors.md)) but has not received a full
third-party security audit. The X.509 `allow_self_signed` options
described in this book exist **for testing only**.
