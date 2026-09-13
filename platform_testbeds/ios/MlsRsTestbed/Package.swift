// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MlsRsTestbed",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "mls_rs_uniffi", targets: ["mls_rs_uniffi"]),
    ],
    targets: [
        // XCFramework produced by scripts/build_ios.sh; contains the
        // RustCrypto-backed mls-rs static library plus the UniFFI FFI
        // header/module map.
        .binaryTarget(
            name: "mls_rs_uniffiFFI",
            path: "../../gen/MlsRsUniffiFFI.xcframework"
        ),
        // Generated UniFFI Swift bindings (copied from
        // gen/swift/mls_rs_uniffi.swift by scripts/test_ios_sim.sh).
        .target(
            name: "mls_rs_uniffi",
            dependencies: ["mls_rs_uniffiFFI"]
        ),
        .testTarget(
            name: "MlsRsE2ETests",
            dependencies: ["mls_rs_uniffi"],
            resources: [.copy("Resources/test_pki")]
        ),
    ]
)
