// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MLSRsUniFFI",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "MLSRsUniFFI",
            targets: ["MLSRsUniFFI"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "MLSRsUniFFIBinaries",
            path: "Artifacts/MLSRsUniFFI.xcframework"
        ),
        .target(
            name: "FFI",
            path: "Sources/FFI",
            publicHeadersPath: "include",
            cSettings: [
                .unsafeFlags(["-fmodules"])
            ]
        ),
        .target(
            name: "MLSRsUniFFI",
            dependencies: [
                "FFI",
                .target(name: "MLSRsUniFFIBinaries")
            ],
            path: "Sources/MLSRsUniFFI",
            linkerSettings: [
                .linkedLibrary("c++"),
                .linkedLibrary("z")
            ]
        ),
    ]
)
