# Verifying the installation

Before wiring MLS into your app, confirm the library actually works in
your environment. Every check below performs a real two-party MLS
handshake — if it passes, key generation, HPKE, signing, AEAD and the
FFI layer are all functioning.

## The 60-second smoke test

Every binding can run this minimal sequence — create two clients, form
a group, exchange one encrypted message:

{{#tabs }}
{{#tab name="Rust" }}

```sh
cargo run --release --manifest-path platform_testbeds/rust-harness/Cargo.toml
```

Expected tail of output:

```text
PASS basic e2e suite 5 (P521Aes256)
...
All scenarios passed.
```

{{#endtab }}
{{#tab name="Kotlin" }}

```sh
platform_testbeds/scripts/test_kotlin.sh        # JVM, no Android SDK needed
# on-device: platform_testbeds/scripts/test_android.sh
```

Expected:

```text
PASS basic e2e P521_AES256
PASS x509-p521-suite5
All Kotlin scenarios passed.
```

{{#endtab }}
{{#tab name="Swift" }}

```sh
platform_testbeds/scripts/test_swift_macos.sh   # macOS host
platform_testbeds/scripts/test_ios_sim.sh       # iOS simulator (XCTest)
```

Expected:

```text
PASS basic e2e p521Aes256
All Swift scenarios passed.
# iOS: "Executed 2 tests, with 0 failures" / ** TEST SUCCEEDED **
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```sh
platform_testbeds/scripts/build_wasm.sh               # emits pkg/ + pkg-async/
node platform_testbeds/wasm/test/node_test.mjs          # Node e2e (sync artifact)
MLS_PKG=async node platform_testbeds/wasm/test/node_test.mjs   # async artifact
cd platform_testbeds/wasm/test && npm install           # once — fake-indexeddb
node platform_testbeds/wasm/test/node_persistence.mjs   # IndexedDB persistence
platform_testbeds/scripts/test_wasm_browser.sh          # headless Chrome, both artifacts
```

Expected:

```text
PASS basic e2e   suite 5:P521Aes256
PASS x509-p521-suite5
All WASM scenarios passed.
PASS persistence: group state survives reload
PASS persistence: key package stays joinable across reload
PASS persistence: wrong storage key fails closed
PASS persistence: delete removes all state
All persistence scenarios passed.
```

{{#endtab }}
{{#endtabs }}

## Cross-language wire interop + differential testing

Same-language tests prove each binding works; `test_interop.sh` proves
two stronger properties **for every cipher suite**:

* **Wire interop** — Kotlin, Swift and WASM each emit a serialized key
  package; the Rust harness (built on direct `mls-rs`, not the binding
  layer) consumes them into a group's welcome + application messages,
  and every binding joins and decrypts. Each binding then emits its own
  encrypted message, which the harness decrypts (`--verify`) using the
  persisted producer group.
* **Differential equality** — same inputs produce the same outputs
  through the bindings as through direct `mls-rs`: every fixture must
  round-trip byte-identically through the binding codec
  (`Message.fromBytes(x).toBytes() == x`), the post-join and
  post-commit `exportTree()` bytes must equal the golden
  `expected_tree_*.bin`, and the roster must equal
  `expected_roster.txt`.

```sh
platform_testbeds/scripts/test_interop.sh   # needs gen bindings + wasm pkg
```

Expected (per suite — all five are run):

```text
  consumer_kp_kotlin.bin: parsed and signature-validated by direct mls-rs
  consumer_msg_kotlin.bin: decrypted by direct mls-rs
PASS kotlin interop + differential (Rust consumed KP+msg, Kotlin matched golden outputs)
PASS swift interop + differential (...)
PASS wasm interop + differential (...)
```

## What each test covers

| Scenario | Proves |
|----------|--------|
| `basic e2e` per suite | keygen, HPKE (KEM), signature, AEAD, tree math for that suite |
| `x509-*` | chain validation, leaf-key matching, credential encoding |
| `writeToStorage` + `loadGroup` | the persistence path |
| commit → welcome → join | the full RFC 9420 handshake |
| `test_interop.sh` | serialized bytes interoperate across Rust/Kotlin/Swift/WASM; binding outputs byte-match direct-Rust ground truth (trees, roster, codec round-trips) for all 5 suites |

## Common installation pitfalls

| Symptom | Cause | Fix |
|---------|-------|-----|
| `missing required module 'mls_rs_uniffiFFI'` (Swift) | XCFramework headers lack `module.modulemap` | repackage via `package_swift.sh` |
| `UnsatisfiedLinkError: mls_rs_uniffi` (JVM) | JNA can't find the dylib | set `-Djna.library.path` / `JNA_LIBRARY_PATH` |
| `getrandom: this target is not supported` (WASM) | `browser` feature not enabled | enable `mls-rs-crypto-rustcrypto/browser` |
| signature verification fails on NIST-curve certs | cert signed with wrong digest | sign P-384→SHA-384, P-521→SHA-512 |
| `DuplicateLeafData` on two clients | same credential reused | each client needs a distinct identity/cert |
