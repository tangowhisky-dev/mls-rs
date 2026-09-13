# mls-rs platform testbeds

End-to-end validation of `mls-rs` with the **RustCrypto** crypto backend
(`mls-rs-crypto-rustcrypto`) and the generated UniFFI / WASM bindings, on
macOS, iOS, Android and the web.

Everything in this folder is **test tooling only** — nothing here ships
with the library. Generated artifacts (bindings, XCFramework, `.so`
files, wasm packages) are reproducible via `scripts/` and are gitignored.

> **Shipping it to your app?** See [INTEGRATION.md](INTEGRATION.md) for
> detailed per-platform instructions and the `scripts/package_*.sh`
> standalone-bundle generators (`dist/`). For the full API reference
> with per-platform examples see the mdBook in
> [`../docs/`](../docs) (`mdbook serve docs/`).

## What is covered

* Cipher suites **1, 2, 3, 5, 7** via RustCrypto:

  | Suite | Name | KEM | AEAD | Signature |
  |-------|------|-----|------|-----------|
  | 1 | `MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519` | X25519 | AES-128-GCM | Ed25519 |
  | 2 | `MLS_128_DHKEMP256_AES128GCM_SHA256_P256` | P-256 | AES-128-GCM | ECDSA P-256/SHA-256 |
  | 3 | `MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519` | X25519 | ChaCha20-Poly1305 | Ed25519 |
  | 5 | `MLS_256_DHKEMP521_AES256GCM_SHA512_P521` | P-521 | AES-256-GCM | ECDSA P-521/SHA-512 |
  | 7 | `MLS_256_DHKEMP384_AES256GCM_SHA384_P384` | P-384 | AES-256-GCM | ECDSA P-384/SHA-384 |

* X.509 credentials via the RustCrypto validator
  (`mls-rs-identity-x509` + `x509-cert`) with chains signed by a
  locally generated test CA (`test_pki/`). Leaf key algorithms:
  Ed25519, P-256, P-384, P-521.

* Every scenario performs a real two-party MLS handshake:
  create group → key package → `add_members` commit → `join_group`
  from welcome → application message encrypt/decrypt → storage
  round-trip.

## Layout

```
platform_testbeds/
├── scripts/            build + test orchestration (see below)
├── rust-harness/       cargo bin exercising the UniFFI API surface
├── wasm/
│   ├── mls-rs-wasm/    wasm-bindgen crate wrapping mls-rs + RustCrypto
│   │                   (IndexedDB-persistent, AES-256-GCM values)
│   ├── test/           Node.js e2e + persistence runners
│   └── web/            minimal browser page + harness
├── ios/
│   ├── src/main.swift  macOS command-line driver (Swift bindings)
│   └── MlsRsTestbed/   SwiftPM package + XCTest for iOS simulator
├── android/
│   ├── e2e.kts         Kotlin/JVM script (same scenarios)
│   └── app/            minimal Gradle app + instrumented test
├── test_pki/           generated CAs + leaf certs/keys (checked in)
└── gen/                generated bindings & XCFramework (gitignored)
```

## Quick start

```sh
platform_testbeds/scripts/env_check.sh     # verify toolchain pieces
platform_testbeds/scripts/run_all.sh       # run every available platform
```

Or run pieces individually:

| Platform | Build | Test |
|----------|-------|------|
| Rust (native) | — | `cargo run --release --manifest-path platform_testbeds/rust-harness/Cargo.toml` |
| WASM → Node | `scripts/build_wasm.sh` | `node platform_testbeds/wasm/test/node_test.mjs` (`MLS_PKG=async` for the async artifact) |
| WASM → persistence | `cd wasm/test && npm install` once | `node wasm/test/node_persistence.mjs` (IndexedDB via fake-indexeddb; reload/wrong-key/delete) |
| WASM → browser | `scripts/build_wasm.sh` | `scripts/test_wasm_browser.sh` (headless Chrome, sync + async) |
| Kotlin/JVM | `scripts/gen_bindings.sh kotlin` | `scripts/test_kotlin.sh` |
| Swift/macOS | `scripts/gen_bindings.sh swift` | `scripts/test_swift_macos.sh` |
| Android | `scripts/build_android.sh` | `scripts/test_android.sh` (emulator/device via `connectedDebugAndroidTest`) |
| iOS | `scripts/build_ios.sh` | `scripts/test_ios_sim.sh` (SwiftPM + `xcodebuild test` on a simulator) |
| **Cross-language wire interop** | `scripts/gen_bindings.sh` + `scripts/build_wasm.sh` | `scripts/test_interop.sh` — Kotlin/Swift/WASM emit key-package bytes that Rust consumes into a welcome each binding joins |

Standalone distributable bundles (see [INTEGRATION.md](INTEGRATION.md)):

| Script | Output |
|--------|--------|
| `scripts/package_kotlin.sh` | `dist/kotlin/` — `.kt` bindings + `jniLibs/` + host lib |
| `scripts/package_swift.sh` | `dist/swift/MlsRsUniffi/` — ready SwiftPM package |
| `scripts/package_wasm.sh` | `dist/wasm/{sync,async}/{web,bundler}/` |

Regenerate the test PKI when needed (uses `openssl` CLI; keys are
exported with `scripts/export_key_json.py`, any Python 3.7+):

```sh
platform_testbeds/scripts/gen_test_pki.sh
```

## Requirements

* Rust ≥ 1.85 with targets:
  `wasm32-unknown-unknown`, `aarch64-apple-ios`, `aarch64-apple-ios-sim`,
  `aarch64-linux-android`, `armv7-linux-androideabi`,
  `x86_64-linux-android`, `i686-linux-android`
* `wasm-bindgen-cli` (`cargo install wasm-bindgen-cli`) + Node.js
* `cargo-ndk` + Android SDK/NDK (`$ANDROID_HOME`) + Gradle ≥ 8 and an
  emulator/device for the on-device test
* Xcode + an iOS simulator for the iOS test
* `kotlinc` for the JVM harness (the repo's own `kotlin_scenarios`
  test additionally needs Maven; these testbeds do not)
* `openssl` CLI for test-PKI generation; Chrome for the browser test

## Notes

* `mls-rs-uniffi` defaults to the RustCrypto backend; `--features openssl`
  selects the OpenSSL provider where available. If both are enabled,
  RustCrypto wins.
* The X.509 `allow_self_signed` client-config flag exists **for these
  tests only**. Do not enable it in production.
* `test_pki/` is generated by `scripts/gen_test_pki.sh`. Certificates
  are signed with the curve-matched digest (P-384 → SHA-384,
  P-521 → SHA-512) as the RustCrypto validator expects.
* `android/local.properties` (sdk.dir) is machine-local and gitignored;
  alternatively export `ANDROID_HOME`.
* **Interop**: every binding serializes MLS values to the same wire
  bytes — `Message.toBytes()`/`Message.fromBytes()` in Kotlin/Swift,
  `Uint8Array` in WASM, `MlsMessage::to_bytes()` in Rust. See
  [INTEGRATION.md §5](INTEGRATION.md) for the full contract, sync/async
  build strategy and per-binding gaps.
