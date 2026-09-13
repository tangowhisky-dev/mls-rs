# Platform notes & limitations

## API parity

| Capability | Rust | Kotlin/Swift (UniFFI) | WASM |
|------------|:----:|:----:|:----:|
| All 5 cipher suites | ✅ | ✅ | ✅ |
| Basic credentials | ✅ | ✅ | ✅ |
| X.509 credentials | ✅ | ✅ | ✅ |
| Key packages, create/join group | ✅ | ✅ | ✅ |
| Message ↔ raw wire bytes | `to_bytes`/`from_bytes` | `toBytes`/`fromBytes` | native `Uint8Array` |
| Add members (immediate + propose) | ✅ | ✅ | ✅ |
| Remove members | ✅ | ✅ (by `SigningIdentity`) | ✅ (by leaf index) |
| Roster / member identity | ✅ | ✅ `members()`, `memberWithIdentity()` | ✅ `members()` |
| Application messages | ✅ | ✅ | ✅ |
| Custom `GroupStateStorage` | ✅ | ✅ (callback trait) | built-in IDB (see below) |
| `exportTree` / `loadGroup` | ✅ | ✅ | ✅ |
| `CommitOutput.groupInfo` | ✅ | ✅ | — |
| `ExtensionList`/`JoinInfo` details | ✅ | ✅ | — |
| Custom proposals/extensions, external commits, PSK, exporters | ✅ | — | — |
| Async API | ✅ | build-time (`mls_build_async`) | build-time (`mls_build_async`) |

The UniFFI surface is intentionally the *messaging-app subset*; Rust
exposes the full library (external commits, PSKs, exporters, custom
extension types — see `mls-rs` rustdoc). WASM differs from UniFFI in
representation (raw `Uint8Array` vs `Message`/`RatchetTree` objects)
and in member addressing (leaf index vs `SigningIdentity`) — see
[interoperability](../concepts/interoperability.md).

## Per-platform

**Android** — `.so`s are built with `--platform 24` (minSdk 24).
`stripDebugDebugSymbols` can't strip the Rust libs — expected, they
ship unstripped. `local.properties`/`ANDROID_HOME` must point at the
SDK.

**iOS** — the XCFramework's `Headers` dir must contain
`module.modulemap` (not the uniffi-suffixed name) or Swift can't see
`RustBuffer` & friends. `package_swift.sh`/`build_ios.sh` handle this.

**WASM** — requires `mls-rs-crypto-rustcrypto/browser`
(`getrandom/js`). Node ≥ 18 works out of the box; browsers need a
secure context for `globalThis.crypto`. `rayon` is disabled in the
wasm crate — keep `default-features = false` on `mls-rs`. Persistence:
`WasmClient.openPersistent`/`openPersistentX509` store MLS state in
IndexedDB with AES-256-GCM-encrypted values (Wire-keystore pattern;
see [persistence](../api/persistence.md) and
[app setup](../manual/app_setup.md)). IndexedDB is browser-only — in
Node the same API works under an `indexedDB` shim
(e.g. `fake-indexeddb`, used by the testbed), otherwise state stays
in-memory.

**macOS** — the same XCFramework's `macos-arm64` slice serves both
SwiftPM apps and plain `swiftc` drivers (see
`platform_testbeds/ios/src/main.swift` + `test_swift_macos.sh`).

## Concurrency & sync/async

`Group` is internally locked — safe to call from multiple
threads/queues; calls are serialized. Callbacks into your
`GroupStateStorage` happen on the caller's thread.

The `mls_build_async` `--cfg` flag selects the async Rust API **at
build time** — a single artifact is either sync or async, never both.
The default artifacts produced by every packaging script are
synchronous:

* **Kotlin/Swift**: all exported methods block — call them off the UI
  thread (`Dispatchers.IO`, `Task`, or a background queue). For a
  `suspend`/`async` surface, rebuild with
  `RUSTFLAGS="--cfg mls_build_async"`; method names and wire types are
  identical, only the calling convention changes.
* **WASM**: `build_wasm.sh`/`package_wasm.sh` emit **both** artifacts —
  `pkg/`/`dist/wasm/sync/` is synchronous (MLS calls return values;
  IndexedDB writes commit in the background — call `flushStorage()` to
  settle them) and `pkg-async/`/`dist/wasm/async/` returns Promises
  (each storage write is awaited inside the call, Wire-CoreCrypto
  style). `openPersistent`/`flushStorage`/`deletePersistentStorage`
  are Promises in *both* artifacts — IndexedDB itself is async.
* **Rust**: set the same flag in your crate to get the `async` API.

Sync and async builds emit identical wire bytes — the choice never
affects cross-platform interop.
