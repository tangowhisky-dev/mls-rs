// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "MLSSwiftBindingsTests",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "MLSSwiftBindings",
            targets: ["MLSSwiftBindings"]),
    ],
    dependencies: [],
    targets: [
        .systemLibrary(
            name: "mls_rs_uniffiFFI",
            path: "Sources/MLSSwiftBindings",
            pkgConfig: nil,
            providers: nil),
        .target(
            name: "MLSSwiftBindings",
            dependencies: ["mls_rs_uniffiFFI"],
            resources: [
                .copy("libmls_rs_uniffi.dylib")
            ],
            cSettings: [
                .headerSearchPath(".")
            ],
            linkerSettings: [
                .linkedLibrary("mls_rs_uniffi", .when(platforms: [.macOS, .iOS])),
                .unsafeFlags(["-LSources/MLSSwiftBindings"], .when(platforms: [.macOS]))
            ]
        ),
        .testTarget(
            name: "MLSSwiftBindingsTests",
            dependencies: ["MLSSwiftBindings"]
        ),
    ]
)