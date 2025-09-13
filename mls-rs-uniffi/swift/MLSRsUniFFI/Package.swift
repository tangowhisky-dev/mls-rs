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
        .target(
            name: "MLSRsUniFFI",
            dependencies: []
        ),
    ]
)
