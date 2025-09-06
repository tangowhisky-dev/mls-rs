// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MLSSwiftBindings",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "MLSSwiftBindings",
            targets: ["MLSSwiftBindings"]
        ),
    ],
    targets: [
        .target(
            name: "MLSSwiftBindings",
            path: "bindings",
            sources: ["mls_rs_uniffi.swift"],
            publicHeadersPath: ".",
            cSettings: [
                .headerSearchPath(".")
            ]
        ),
        .testTarget(
            name: "MLSSwiftBindingsTests",
            dependencies: ["MLSSwiftBindings"],
            path: "tests"
        ),
    ]
)
