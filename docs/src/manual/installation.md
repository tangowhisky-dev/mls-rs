# Installation & integration

Each platform below ends with a copyable artifact. The full walkthrough
with Gradle/SwiftPM/bundler snippets lives in
[`platform_testbeds/INTEGRATION.md`](https://github.com/awslabs/mls-rs/tree/main/platform_testbeds/INTEGRATION.md);
this page is the short path.

{{#tabs }}
{{#tab name="Rust" }}

Add the crates to your `Cargo.toml`:

```toml
[dependencies]
mls-rs = { version = "0.56", features = ["x509"] }
mls-rs-core = "0.27"
mls-rs-crypto-rustcrypto = { version = "0.22.1", features = ["x509"] }
mls-rs-identity-x509 = "0.21"          # X.509 identity provider
mls-rs-provider-sqlite = "0.23"        # optional: durable storage
```

For `wasm32-unknown-unknown` builds add `default-features = false` (no
`rayon`) and enable `mls-rs-crypto-rustcrypto/browser`
(→ `getrandom/js`). The `platform_testbeds/wasm/mls-rs-wasm` manifest
shows the exact feature set.

{{#endtab }}
{{#tab name="Kotlin" }}

Generate the standalone bundle:

```sh
platform_testbeds/scripts/package_kotlin.sh
# flags: --skip-android  --skip-host  --debug
```

Output (`platform_testbeds/dist/kotlin/`):

```
bindings/uniffi/mls_rs_uniffi/mls_rs_uniffi.kt
jniLibs/{arm64-v8a,armeabi-v7a,x86_64,x86}/libmls_rs_uniffi.so
host/<triple>/libmls_rs_uniffi.dylib       # JVM/desktop
```

**Android**: copy `jniLibs/` into `app/src/main/jniLibs/` and the `.kt`
file into your sources; add
`implementation("net.java.dev.jna:jna:5.18.1@aar")`. Requires
`minSdk ≥ 24`.

**JVM**: put the `.kt` file on your source path, depend on the JNA JAR,
and run with `-Djna.library.path=<…>/host/<triple>` (or set
`JNA_LIBRARY_PATH`).

{{#endtab }}
{{#tab name="Swift" }}

Generate a ready SwiftPM package:

```sh
platform_testbeds/scripts/package_swift.sh            # iOS + sim + macOS
platform_testbeds/scripts/package_swift.sh --macos-only
```

Output: `platform_testbeds/dist/swift/MlsRsUniffi/` containing the
`MlsRsUniffiFFI.xcframework` (static libs + FFI module map), the
generated `mls_rs_uniffi.swift`, and a `Package.swift`.

Add it as a **local package** (`Package.swift`:
`.package(path: ".../MlsRsUniffi")`, or Xcode → Add Package Dependencies
→ Add Local) and depend on the `mls_rs_uniffi` product.

{{#endtab }}
{{#tab name="Web (WASM)" }}

Generate the JS/WASM bundles:

```sh
platform_testbeds/scripts/package_wasm.sh
```

Output (`platform_testbeds/dist/wasm/`):

```
web/      native ES modules — browsers & Node ≥ 18
bundler/  for webpack / vite / rollup wasm plugins
```

Serve `.wasm` as `application/wasm`. The wasm crate
(`platform_testbeds/wasm/mls-rs-wasm`) can be copied into your own
workspace to customize the exported API — repoint its `mls-rs*` path
deps to crates.io versions when vendoring.

{{#endtab }}
{{#endtabs }}
