// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "MlsRsExample",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    dependencies: [
        .package(name: "MlsRs", path: "../../bindings/swift")
    ],
    targets: [
        .executableTarget(
            name: "MlsRsExample",
            dependencies: ["MlsRs"],
            path: "Sources"
        )
    ]
)
