# Swift Bindings Workspace Overview

This `swift/` directory contains everything needed to build, package, test, and integrate the Swift (iOS / macOS) bindings for the `mls-rs` Messaging Layer Security implementation.

It supports two parallel usage models:
1. **Modern Packaged Flow (Recommended)** – A self‑contained Swift Package (`MLSRsUniFFI`) wrapping an XCFramework with static MLS artifacts.
2. **Legacy / Raw Bindings Flow** – Direct access to the raw UniFFI outputs in `bindings/` plus an ad-hoc test package in `tests/`.

---
## 📂 Directory Structure

```
swift/
├── MLSRsUniFFI/              # Generated Swift Package (XCFramework + sources)
│   ├── Artifacts/            # XCFramework: static libs for iOS device + simulator
│   ├── Package.swift         # Package manifest (binary + C FFI + Swift targets)
│   └── Sources/
│       ├── FFI/              # C surface (header + modulemap + placeholder .c)
│       │   └── include/
│       │       ├── mls_rs_uniffiFFI.h
│       │       └── module.modulemap
│       └── MLSRsUniFFI/      # High‑level Swift API (generated UniFFI Swift)
│           └── mls_rs_uniffi.swift
│
├── bindings/                 # Raw UniFFI output (legacy; was primary earlier)
│   ├── mls_rs_uniffi.swift
│   ├── mls_rs_uniffiFFI.h
│   ├── mls_rs_uniffiFFI.modulemap
│   └── libmls_rs_uniffi.dylib (if built as dynamic lib during development)
│
├── tests/                    # Minimal SwiftPM test harness (legacy style)
│   ├── Package.swift
│   ├── Sources/MLSSwiftBindings/ (raw bindings copy + module map)
│   └── Tests/MLSSwiftBindingsTests/MLSSwiftBindingsTests.swift
│
├── xcode-test/               # Comprehensive XCTest-style CLI test suite
│   ├── run_xcode_test.sh     # Driver (cipher suite selection + release/debug)
│   ├── main.swift            # Entry point orchestrating category tests
│   ├── client_tests.swift
│   ├── group_tests.swift
│   ├── encryption_tests.swift
│   ├── advanced_tests.swift
│   ├── groupstate_storage_tests.swift
│   ├── comprehensive_api_tests.swift
│   ├── error_and_storage_tests.swift
│   ├── p521_cipher_suite_test.swift
│   ├── all_cipher_suites_test.swift
│   ├── cipher_suite_analysis.swift
│   └── test_simple.sh        # Very small smoke example
│
├── examples/                 # Practical usage examples (integration patterns)
│   ├── ServerIntegrationExample.swift
│   ├── RealmUsageExample.swift
│   └── RealmStorageExample.swift
│
├── docs/                     # Narrative guides / advanced topics
│   ├── CustomStorageGuide.md
│   ├── ServerCommunicationGuide.md
│   └── ServerIntegrationExample.swift (duplicate for documentation context)
│
├── CIPHER_SUITE_ANALYSIS.md  # Deep-dive notes (cipher suite behavior)
├── CIPHER_SUITE_VERIFICATION.rs # Rust helper used in analysis
├── IMPLEMENTATION_PLAN.md    # Internal planning notes
├── SWIFT_TESTS_UPDATE_SUMMARY.md # Change log for test evolution
└── README.md (this file)
```

---
## 🚀 Generation Workflow

Bindings + package artifacts are produced by the top-level script (run from `mls-rs-uniffi/`):

```bash
./generate_swift_bindings.sh            # Debug (includes symbols)
./generate_swift_bindings.sh --release  # Optimized size/perf
```

This script:
1. Builds the Rust crate for required iOS targets (arm64 device + arm64 simulator).
2. Invokes UniFFI to generate Swift sources (`mls_rs_uniffi.swift`, header, module map).
3. Applies minor patches (e.g., Swift `Error` conformance fix, naming adjustments).
4. Assembles an XCFramework from static libraries (no embedded headers to avoid module duplication).
5. Constructs or refreshes the `MLSRsUniFFI/` Swift Package (binary target + C FFI + Swift wrapper).
6. Ensures a placeholder C source exists (`ffi_placeholder.c`) so the FFI target emits an object file.
7. Leaves legacy raw files in `bindings/` for inspection / diffing.

> NOTE: If you previously relied on dragging `.dylib` outputs into Xcode, migrate to the package-based flow—no manual linker flags needed beyond what `Package.swift` sets (`-lc++`, `-lz`).

---
## 📦 Using the Swift Package in an App

### Add as Local Package (Xcode GUI)
1. Run the generation script (see above).
2. In Xcode: File > Add Packages… > Add Local…
3. Select `mls-rs-uniffi/swift/MLSRsUniFFI`.
4. Add product `MLSRsUniFFI` to your app target.
5. Build—module `MLSRsUniFFI` becomes importable.

### Add via `Package.swift`
```swift
// Inside your application Package.swift
.dependencies: [
    .package(path: "../relative/path/to/mls-rs-uniffi/swift/MLSRsUniFFI")
],
.targets: [
    .target(
        name: "YourApp",
        dependencies: ["MLSRsUniFFI"]
    )
]
```

### Basic Usage
```swift
import MLSRsUniFFI

let cfg = clientConfigDefault()
let kp = try generateSignatureKeypair(cipherSuite: .p256Aes128)
let cid = "alice".data(using: .utf8)!
let alice = Client(id: cid, signatureKeypair: kp, clientConfig: cfg)
let group = try alice.createGroup(groupId: nil)
try group.writeToStorage()
```

### Regenerating After Rust API Changes
```bash
cd mls-rs-uniffi
./generate_swift_bindings.sh
# If Xcode caches old symbols: Clean Build Folder (Shift+Cmd+K) & rebuild
```
If the module fails to refresh: remove the local package reference and re-add it.

---
## 🧪 Testing Layers

| Layer | Purpose | Location | Invocation |
|-------|---------|----------|-----------|
| Smoke / Minimal | Quick compile + symbol sanity | examples / test_simple.sh | `./xcode-test/test_simple.sh` |
| Comprehensive CLI Suite | Full protocol coverage (15 categories, all cipher suites) | `xcode-test/` | `./run_xcode_test.sh [suiteId] [--release]` |
| Legacy SwiftPM Tests | Basic XCTest style; legacy artifact usage | `tests/` | `cd tests && swift test` |

### Comprehensive Suite Details
- **Selectable Cipher Suite**: pass ID (1–7). Omitting runs defaults defined in script.
- **Debug vs Release**: Append `--release` for optimized artifact.
- **Categories Covered**: Client, Groups, Encryption, Storage, Error Handling, Tree/State, Interop, High-Security (P-521), Aggregated API flows, Cipher Suite analysis, etc.

Examples:
```bash
cd swift/xcode-test
./run_xcode_test.sh 2          # P-256 debug
./run_xcode_test.sh 5 --release # P-521 optimized
```

### Legacy Tests (Optional)
```bash
cd swift/tests
swift test
```
These are retained for historical comparison and faster minimal cycles.

---
## 💡 Examples & Docs

| File | Focus |
|------|-------|
| `examples/RealmUsageExample.swift` | Demonstrates storing MLS-related data with Realm (conceptual). |
| `examples/RealmStorageExample.swift` | Illustrates a storage adapter flow. |
| `examples/ServerIntegrationExample.swift` | Sketches server round-trips / key package distribution. |
| `docs/CustomStorageGuide.md` | Building custom GroupState and key storage. |
| `docs/ServerCommunicationGuide.md` | Server API design considerations. |
| `docs/ServerIntegrationExample.swift` | Same as example, duplicated for doc context. |

> Treat examples as starting points—they may need adaptation to your production architecture (DI, logging, persistence strategy).

---
## 🔧 Troubleshooting

| Issue | Likely Cause | Resolution |
|-------|--------------|-----------|
| `No such module 'MLSRsUniFFI'` | Package not added or stale build cache | Re-add local package; Clean Build Folder. |
| Module redefinition error | Duplicate module maps (headers inside XCFramework + FFI target) | Ensure script (current version) omits `-headers` when creating XCFramework. |
| Missing `FFI.o` | Header-only C target | Keep `ffi_placeholder.c` intact. |
| Linker error for `-lc++` / `-lz` | Stripped flags or manual override | Verify `Package.swift` includes `linkerSettings`. |
| Need Intel simulator slice | Only arm64 built | Extend script to also build `x86_64-apple-ios-sim` and re-create XCFramework. |
| macOS support needed | Only iOS slices built | Add macOS targets (aarch64 + optionally x86_64) to script. |
| Swift Error extension conflict | UniFFI generated conflicting `extension Error: Error` | Script already patches; verify regenerated file includes `Swift.Error`. |

---
## 🧱 Extending the Build

Add macOS slices:
```bash
# Inside generate_swift_bindings.sh (conceptual snippet)
for TARGET in aarch64-apple-ios aarch64-apple-ios-sim aarch64-apple-darwin; do
  cargo build --target $TARGET --release # or debug
  # collect libmls_rs_uniffi.a
done
# include new -library arguments for macOS slice when invoking xcodebuild -create-xcframework
```

Add Catalyst:
```bash
# Add target: x86_64-apple-ios-macabi (and/or arm64-apple-ios-macabi on Apple Silicon)
```

---
## 🔐 Security & Logging Guidance
- Prefer structured logging (e.g., `CustomLogger.logInfo`) over `print` in app-level integration.
- Keep cryptographic key material out of logs.
- Regenerate and re-test after changing any Rust crypto provider configuration.

---
## 🛠 Maintenance Strategy
| Task | Frequency | Notes |
|------|-----------|-------|
| Regenerate bindings | When Rust public API changes | Commit updated `MLSRsUniFFI` directory for consumers. |
| Run comprehensive tests | Before releases / weekly CI | Cover all cipher suites. |
| Add new cipher suite | Rare (spec updates) | Update UniFFI interfaces + test mappings. |
| Update storage example | As persistence model evolves | Ensure docs reflect real-world patterns. |

---
## ✅ Quick Smoke Checklist (Before Committing)
- [ ] `./generate_swift_bindings.sh` completes without errors
- [ ] `swift/xcode-test/run_xcode_test.sh 2` passes
- [ ] `swift/tests` minimal tests pass (optional)
- [ ] No stray `print` statements introduced in high-level API layer
- [ ] README (this file) reflects current script behavior

---
## 📄 License
This Swift bindings workspace inherits the repository’s dual Apache-2.0 / MIT licensing.

---
## 🙋 Support / Contribution
- For API shape discussions: open an issue in main repo referencing "Swift bindings".
- For script improvements: include before/after tree + test results.
- For security concerns: use the project’s responsible disclosure process.

Enjoy building secure group messaging with MLS! 🔐
