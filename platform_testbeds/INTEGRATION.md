# Integrating mls-rs + RustCrypto into your app

This guide explains how to build, package and consume `mls-rs` with the
pure-Rust **RustCrypto** backend on every supported platform:

| Your app | What you build | Entry point |
|----------|----------------|-------------|
| Rust (native/server) | crates from crates.io/path deps | `mls_rs::Client` |
| Kotlin / Java | `mls-rs-uniffi` native lib + generated `.kt` | `uniffi.mls_rs_uniffi.*` |
| Swift (iOS, macOS) | XCFramework + generated `.swift` | `mls_rs_uniffi` module |
| Web / Node (JS/TS) | wasm-bindgen package | `mls_rs_wasm` module |

One Rust codebase backs all of them: suites **1, 2, 3, 5, 7** and
X.509 credentials behave identically everywhere.

## 0. One-time toolchain setup

```sh
# Rust targets — install the ones you need
rustup target add wasm32-unknown-unknown \
    aarch64-apple-ios aarch64-apple-ios-sim \
    aarch64-linux-android armv7-linux-androideabi \
    x86_64-linux-android i686-linux-android

cargo install cargo-ndk wasm-bindgen-cli   # Android + WASM packaging
# Android SDK/NDK: export ANDROID_HOME=~/Library/Android/sdk
# iOS/macOS: Xcode (xcodebuild). Web: Node.js for smoke tests.
```

Verify everything: `platform_testbeds/scripts/env_check.sh`.

## 1. Rust applications

No FFI — depend on the crates directly.

```toml
[dependencies]
mls-rs = { version = "0.56", features = ["x509"] }
mls-rs-core = "0.27"
mls-rs-crypto-rustcrypto = { version = "0.22.1", features = ["x509"] }
mls-rs-identity-x509 = "0.21"
# Optional: persistent group/key-package storage backed by SQLite
mls-rs-provider-sqlite = "0.23"
```

Basic credential client + group flow:

```rust
use mls_rs::{CipherSuite, Client};
use mls_rs::identity::basic::BasicIdentityProvider;
use mls_rs::identity::SigningIdentity;
use mls_rs_crypto_rustcrypto::RustCryptoProvider;
use mls_rs_core::identity::BasicCredential;
use mls_rs_core::crypto::{SignatureSecretKey, SignaturePublicKey};

let provider = RustCryptoProvider::default();
let suite = CipherSuite::P521_AES256; // 1,2,3,5,7 all supported

let (secret, public) = provider
    .cipher_suite_provider(suite).unwrap()
    .signature_key_generate().unwrap();

let identity = SigningIdentity::new(
    BasicCredential::new(b"alice".to_vec()).into_credential(),
    public,
);

let alice = Client::builder()
    .crypto_provider(provider)
    .identity_provider(BasicIdentityProvider::new())
    .signing_identity(identity, secret, suite)
    .build();

let group = alice.create_group(Default::default(), Default::default(), None)?;
```

For X.509 credentials, build an `X509IdentityProvider` with a
`SubjectIdentityExtractor` + `X509Validator` (root CAs, optional
`allow_self_signed` for tests) — see `platform_testbeds/wasm/mls-rs-wasm/src/lib.rs`
and `mls-rs-uniffi/src/config.rs` for complete, working implementations.

**Test it**: `cargo run --release --manifest-path platform_testbeds/rust-harness/Cargo.toml`
exercises all five suites + X.509 through the same code path.

## 2. Kotlin / Java (Android + JVM desktop)

### 2.1 Generate the package

```sh
platform_testbeds/scripts/package_kotlin.sh              # host + Android
platform_testbeds/scripts/package_kotlin.sh --skip-android   # JVM only
```

Produces `platform_testbeds/dist/kotlin/`:

```
bindings/uniffi/mls_rs_uniffi/mls_rs_uniffi.kt   # add to your sources
jniLibs/arm64-v8a|armeabi-v7a|x86|x86_64/libmls_rs_uniffi.so
host/<host-triple>/libmls_rs_uniffi.dylib        # JVM/desktop
```

### 2.2 Android app

Copy into your app module:

```
app/src/main/jniLibs/<abi>/libmls_rs_uniffi.so
app/src/main/java/uniffi/mls_rs_uniffi/mls_rs_uniffi.kt
```

```kotlin
dependencies {
    implementation("net.java.dev.jna:jna:5.18.1@aar")
}
```

`minSdk` 24+ matches the packaged `.so` files (built with
`cargo ndk --platform 24`). See `platform_testbeds/android/app/` for a
complete minimal module.

### 2.3 JVM desktop / server

- Put `mls_rs_uniffi.kt` on your source path, add
  `net.java.dev.jna:jna:5.18.1` to your build.
- Point JNA at the host lib, either:
  - run with `-Djna.library.path=<dist>/kotlin/host/<triple>`, or
  - set env `JNA_LIBRARY_PATH=<dist>/kotlin/host/<triple>`.

### 2.4 Use it

```kotlin
import uniffi.mls_rs_uniffi.*

val suite = CipherSuite.P521_AES256
val key = generateSignatureKeypair(suite)
val client = Client("alice".toByteArray(), key, clientConfigDefault())

val group = client.createGroup(null)
val commit = group.addMembers(listOf(bob.generateKeyPackageMessage()))
group.processIncomingMessage(commit.commitMessage)
val bobGroup = bob.joinGroup(null, commit.welcomeMessage!!).group

val ct = group.encryptApplicationMessage("hello".toByteArray())
val msg = bobGroup.processIncomingMessage(ct)   // ReceivedMessage.ApplicationMessage

// X.509 client
val cfg = clientConfigDefault().copy(rootCaCertificates = listOf(rootCaDer))
val x509 = Client.newWithX509(listOf(leafCertDer), keypair, cfg)
```

### 2.5 Test it

- JVM: `platform_testbeds/scripts/test_kotlin.sh` (10 scenarios)
- Device/emulator: `platform_testbeds/scripts/test_android.sh`
  (`gradle connectedDebugAndroidTest` against `android/app`)

## 3. Swift (iOS + macOS)

### 3.1 Generate the package

```sh
platform_testbeds/scripts/package_swift.sh             # iOS + sim + macOS
platform_testbeds/scripts/package_swift.sh --macos-only
```

Produces `platform_testbeds/dist/swift/MlsRsUniffi/` — a complete
SwiftPM package (XCFramework with static libs + generated bindings +
`Package.swift`).

### 3.2 Add to your app

**Option A — local SwiftPM dependency.** In your app `Package.swift`:

```swift
.package(path: "path/to/dist/swift/MlsRsUniffi")
// target dependency: .product(name: "mls_rs_uniffi", package: "MlsRsUniffi")
```

**Option B — Xcode UI.** File → Add Package Dependencies → Add Local →
pick `dist/swift/MlsRsUniffi`. (Or drag `MlsRsUniffiFFI.xcframework`
into your target plus `mls_rs_uniffi.swift` into your sources.)

### 3.3 Use it

```swift
import mls_rs_uniffi

let key = try generateSignatureKeypair(cipherSuite: .p521Aes256)
let alice = try Client(id: Data("alice".utf8), signatureKeypair: key,
                       clientConfig: clientConfigDefault())

let group = try alice.createGroup(groupId: nil)
let commit = try group.addMembers(keyPackages: [try bob.generateKeyPackageMessage()])
_ = try group.processIncomingMessage(message: commit.commitMessage)
let bobGroup = try bob.joinGroup(ratchetTree: nil,
                                 welcomeMessage: commit.welcomeMessage!).group

let ct = try group.encryptApplicationMessage(message: Data("hello".utf8))
let received = try bobGroup.processIncomingMessage(message: ct)
// received == .applicationMessage(index, data)

// X.509 client
var cfg = clientConfigDefault()
cfg.rootCaCertificates = [rootCaDer]
let x509 = try Client.newWithX509(certificateChain: [leafDer],
                                  signatureKeypair: keypair, clientConfig: cfg)
```

### 3.4 Test it

- iOS simulator: `platform_testbeds/scripts/test_ios_sim.sh`
  (auto-detects an available iPhone simulator; override with
  `IOS_DESTINATION="platform=iOS Simulator,name=…"`)
- macOS CLI: `platform_testbeds/scripts/test_swift_macos.sh`
- Standalone package sanity: `swift build --package-path dist/swift/MlsRsUniffi`

## 4. WebAssembly (browser + Node)

UniFFI has no JS backend, so the WASM surface is a wasm-bindgen crate:
`platform_testbeds/wasm/mls-rs-wasm`. It mirrors the UniFFI API
(`WasmClient`, `WasmGroup`, `WasmCipherSuite`, …). To customise the API,
copy that crate into your workspace; it builds from path deps on this
repo — repoint them to crates.io versions if you vendor it out.

### 4.1 Generate the package

```sh
platform_testbeds/scripts/package_wasm.sh
```

Produces `platform_testbeds/dist/wasm/`:

```
sync/web/, sync/bundler/    synchronous API; storage writes run in the
                            background — settle with flushStorage()
async/web/, async/bundler/  `mls_build_async` build — every MLS call is
                            a Promise and storage writes are awaited
                            (Wire-CoreCrypto-style API)
```

Requirements baked into the crate: `mls-rs-crypto-rustcrypto`'s
`browser` feature (→ `getrandom/js`, CSPRNG from `globalThis.crypto`)
and no `rayon` (not wasm-compatible).

### 4.2 Use it

```js
import init, {
  WasmClient, WasmCipherSuite, WasmSignatureKeypair,
  generate_signature_keypair,
} from "./dist/wasm/web/mls_rs_wasm.js";

await init();   // loads + instantiates the .wasm

const suite = WasmCipherSuite.P521Aes256;
const key = await generate_signature_keypair(suite);   // Promise in the
                                                     // async artifact
const alice = new WasmClient(new TextEncoder().encode("alice"), key);

const group = await alice.createGroup();
const commit = await group.addMembers([await bob.generateKeyPackageMessage()]);
await group.processIncomingMessage(commit.commit_message);
const bobGroup = await bob.joinGroup(commit.welcome_message);

const ct = await group.encryptApplicationMessage(new TextEncoder().encode("hi"));
const msg = await bobGroup.processIncomingMessage(ct);
// msg.kind === "application", msg.data is a Uint8Array

// X.509 client (chains/keys as Uint8Array)
const x509 = WasmClient.newX509([leafDer], [rootCaDer], /*allowSelfSigned*/ false, keypair);
```

(`await` is harmless on the sync artifact — every snippet above works
against both builds.)

**Persistent storage** (browser + Node with an `indexedDB` shim):
`openPersistent`/`openPersistentX509` keep group state, epoch secrets
and key-package init keys in an IndexedDB database whose values are
AES-256-GCM encrypted under an app-supplied 32-byte key:

```js
const storageKey = new Uint8Array(32);        // app-generated, app-kept
crypto.getRandomValues(storageKey);
const alice = await WasmClient.openPersistent("device-1", id, keypair, storageKey);
await alice.createGroup(groupId);
await alice.flushStorage();                    // settle background writes
// …reload…
const again = await WasmClient.openPersistent("device-1", id, keypair, storageKey);
const group2 = await again.loadGroup(groupId); // state survived
```

The MLS database is dedicated to MLS state — keep app data in your own
stores. `client.close()` releases the IDB connection;
`WasmClient.deletePersistentStorage(name)` deletes the database
(browsers block deletes while connections are open).

Serving notes: serve `.wasm` as `application/wasm`; with a bundler use
`dist/wasm/*/bundler/` and your plugin's standard wasm wiring.

### 4.3 Test it

```sh
cd platform_testbeds/wasm/test && npm install          # once — fake-indexeddb
node platform_testbeds/wasm/test/node_test.mjs         # Node e2e (sync)
MLS_PKG=async node platform_testbeds/wasm/test/node_test.mjs
node platform_testbeds/wasm/test/node_persistence.mjs  # IDB persistence (sync)
MLS_PKG=async node platform_testbeds/wasm/test/node_persistence.mjs
platform_testbeds/scripts/test_wasm_browser.sh         # headless Chrome, both artifacts
```

## 5. Cross-platform interoperability

The bindings are designed so Kotlin, Swift, WASM and Rust clients sit
in **the same MLS group**. The rules:

- **The wire boundary is raw MLS bytes.** Serialize outbound values and
  parse inbound ones with the same codec on every platform:

  | Direction | Rust | Kotlin | Swift | WASM |
  |---|---|---|---|---|
  | message → bytes | `msg.to_bytes()` | `msg.toBytes()` | `msg.toBytes()` | *(already `Uint8Array`)* |
  | bytes → message | `MlsMessage::from_bytes(b)` | `Message.fromBytes(b)` | `Message.fromBytes(bytes: b)` | *(pass bytes directly)* |
  | tree → bytes | `tree.to_bytes()` | `tree.bytes` | `tree.bytes` | *(already bytes)* |
  | bytes → tree | `ExportedTree::from_bytes(b)` | `RatchetTree(b)` | `RatchetTree(bytes: b)` | *(pass bytes directly)* |

  Key packages, welcomes, commits, group info, proposals and
  ciphertexts are all `Message`/`MlsMessage` at the wire level. Never
  stringify them; Base64-wrap at your app protocol layer if the
  channel is text-only.

- **One cipher suite per group** — pick one of `1,2,3,5,7` and generate
  every client's key packages for it, on every platform.
- **`useRatchetTreeExtension`: leave `true`** (default) so the tree
  travels inside the welcome and `joinGroup(welcome)` works identically
  everywhere. If disabled, deliver `CommitOutput.ratchetTree` bytes
  alongside each welcome.
- **Key-package storage decides restart-joinability** — a welcome can
  only be joined while the referenced key package's init key is still
  in storage. WASM `openPersistent*` persists them (IndexedDB); the
  in-memory stores (WASM `new`, default UniFFI/Rust) lose them on
  restart — publish a fresh key package after restarting those.
- **Sync vs async is a build-time choice.** `mls_build_async` is a
  `--cfg` rustflag — one artifact is either sync or async, not both.
  Default artifacts are synchronous: call binding methods off the UI
  thread (`Dispatchers.IO`, `Task`, Web Worker). For Kotlin `suspend`/
  Swift `async` bindings, rebuild with
  `RUSTFLAGS="--cfg mls_build_async"` — identical names and wire types.
  Wire interop is unaffected either way.

**Prove it:** `scripts/test_interop.sh` runs a real cross-language
exchange **for every cipher suite** — Kotlin, Swift and WASM each emit
a serialized key package; the Rust harness (built on direct `mls-rs`)
consumes them, commits them into a group and writes a welcome +
encrypted messages that each binding joins/decrypts. It is also a
**differential test**: the harness emits golden expected values
(`expected_tree_*.bin`, `expected_roster.txt`, a second commit), and
each binding must reproduce the direct-Rust outputs byte-for-byte —
`exportTree()` after join and after commit, the final roster, and
codec round-trips. In the reverse direction each binding emits
`consumer_msg_<lang>.bin`, which the harness decrypts from the
persisted producer group (`--verify`).

```sh
platform_testbeds/scripts/gen_bindings.sh && \
platform_testbeds/scripts/build_wasm.sh && \
platform_testbeds/scripts/test_kotlin.sh && \
platform_testbeds/scripts/test_interop.sh
```

### Remaining binding gaps (by design)

| Capability | Kotlin/Swift | WASM |
|---|---|---|
| remove member | `removeMembers([SigningIdentity])` — identities from `members()`, `memberWithIdentity()`, message `sender`, or `SigningIdentity.newBasic/newX509` | `removeMembers([leafIndex])` — indexes from `members()` |
| persistence | `GroupStateStorage` callback trait | built-in IDB (`openPersistent*`, AES-256-GCM values) |
| external commits, PSK, exporters, custom proposals | Rust only | Rust only |
| `CommitOutput.groupInfo` | exposed | not exposed |

## 6. What your app must provide

- **Persistence** — UniFFI keeps group state in memory; implement the
  `GroupStateStorage` callback interface (Swift/Kotlin supply a
  class/closure) or use `mls-rs-provider-sqlite` in Rust. On web,
  `WasmClient.openPersistent*` persists MLS state in IndexedDB with
  AES-256-GCM-encrypted values (Wire-keystore model) — app data stays
  in your own storage. `writeToStorage()` / `loadGroup()` /
  `flushStorage()` are the hooks.
- **Transport** — mls-rs emits/consumes `MlsMessage` byte arrays.
  Publish key packages; fan out commits/welcomes/ciphertexts yourself.

  A complete walkthrough — concrete storage implementations, a
  delivery-service interface, the startup sequence and the message
  loop — is in `docs/src/manual/app_setup.md` (the mdBook's "Wiring
  MLS into your app" chapter).

## 7. Reference

Cipher suites exposed everywhere:

| `CipherSuite` | MLS name | Sig. key encoding (pub / secret) |
|---|---|---|
| `Curve25519Aes128` (1) | X25519/AES-128/Ed25519 | 32 B / 64 B keypair |
| `P256Aes128` (2) | P-256/AES-128/ECDSA | 65 B SEC1 / 32 B scalar |
| `Curve25519ChaCha` (3) | X25519/ChaCha20/Ed25519 | 32 B / 64 B keypair |
| `P521Aes256` (5) | P-521/AES-256/ECDSA-SHA512 | 133 B SEC1 / 66 B scalar |
| `P384Aes256` (7) | P-384/AES-256/ECDSA-SHA384 | 97 B SEC1 / 48 B scalar |

Feature flags on `mls-rs-uniffi`: `rustcrypto` (default, all platforms)
or `openssl` (opt-in; RustCrypto wins if both). `allow_self_signed` in
`ClientConfig` exists **for testing only**.

Packaging script cheat-sheet:

| Script | Output |
|---|---|
| `scripts/package_kotlin.sh [--skip-android|--skip-host|--debug]` | `dist/kotlin/` |
| `scripts/package_swift.sh [--macos-only]` | `dist/swift/MlsRsUniffi/` |
| `scripts/package_wasm.sh` | `dist/wasm/{web,bundler}/` |
