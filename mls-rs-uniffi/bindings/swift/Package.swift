// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MlsRs",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "MlsRs", targets: ["MlsRs"]),
        .executable(name: "MLSExample", targets: ["MLSExample"]),
        .executable(name: "MLSStorageExample", targets: ["MLSStorageExample"]),
        .executable(name: "SwiftDataExample", targets: ["SwiftDataExample"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "MlsRs",
            dependencies: ["MlsRsFFI"],
            path: "Sources/MlsRs"
        ),
        .executableTarget(
            name: "MLSExample",
            dependencies: ["MlsRs"],
            path: "Sources/MLSExample"
        ),
        .executableTarget(
            name: "MLSStorageExample",
            dependencies: ["MlsRs"],
            path: "Sources/MLSStorageExample"
        ),
        .executableTarget(
            name: "SwiftDataExample",
            dependencies: ["MlsRs"],
            path: "Sources/SwiftDataExample"
        ),
        .binaryTarget(
            name: "MlsRsFFI",
            path: "MlsRsFFI.xcframework"
        ),
        .testTarget(
            name: "MlsRsTests",
            dependencies: ["MlsRs"],
            path: "Tests/MlsRsTests"
        )
    ]
)
