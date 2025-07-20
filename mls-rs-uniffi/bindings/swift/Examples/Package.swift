// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MLSExample",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "MLSExample",
            dependencies: [
                .product(name: "MlsRs", package: "mls-rs-swift")
            ]
        )
    ]
)
