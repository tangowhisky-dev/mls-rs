#!/bin/bash
# Script to generate Swift bindings for mls-rs-uniffi using UniFFI
# Usage: ./generate_swift_bindings.sh [--release] [--ios]
#   --release: Build and use release version of the library (default: debug)
#   --ios: Build for iOS targets and create Swift Package (default: macOS only)

set -e

# Parse command line arguments
BUILD_MODE="debug"
CARGO_FLAGS=""
IOS_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_MODE="release"
            CARGO_FLAGS="--release"
            shift
            ;;
        --ios)
            IOS_BUILD=true
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 [--release] [--ios]"
            exit 1
            ;;
    esac
done

if [ "$IOS_BUILD" = true ]; then
    echo "🛠️ Building mls-rs-uniffi $BUILD_MODE for iOS targets..."

    # Set up environment for iOS cross-compilation with vendored OpenSSL
    export OPENSSL_STATIC=1
    export OPENSSL_VENDORED=1
    export IPHONEOS_DEPLOYMENT_TARGET=17.0

    echo "🔧 Cross-compilation configuration:"
    echo "   OPENSSL_STATIC: $OPENSSL_STATIC"
    echo "   OPENSSL_VENDORED: $OPENSSL_VENDORED"
    echo "   IPHONEOS_DEPLOYMENT_TARGET: $IPHONEOS_DEPLOYMENT_TARGET"

    # Clean previous build artifacts for iOS
    echo "🧹 Cleaning previous iOS build artifacts..."
    cargo clean --target aarch64-apple-ios
    cargo clean --target aarch64-apple-ios-sim

    # Build for iOS device (arm64)
    echo "📱 Building for iOS device (arm64)..."
    cargo build --target aarch64-apple-ios -p mls-rs-uniffi --features "mls-rs-crypto-openssl/vendored" $CARGO_FLAGS

    # Build for iOS simulator (arm64 only - no x86_64)
    echo "📱 Building for iOS simulator (arm64)..."
    cargo build --target aarch64-apple-ios-sim -p mls-rs-uniffi --features "mls-rs-crypto-openssl/vendored" $CARGO_FLAGS

    # Use iOS device library for binding generation
    LIB_PATH="../target/aarch64-apple-ios/$BUILD_MODE/libmls_rs_uniffi.dylib"

    echo "📦 iOS libraries created:"
    echo "   📱 Device: ../target/aarch64-apple-ios/$BUILD_MODE/libmls_rs_uniffi.dylib"
    echo "   🖥️ Simulator: ../target/aarch64-apple-ios-sim/$BUILD_MODE/libmls_rs_uniffi.dylib"
else
    echo "🛠️ Building mls-rs-uniffi $BUILD_MODE dylib for macOS..."
    cargo build --target aarch64-apple-darwin -p mls-rs-uniffi $CARGO_FLAGS
    LIB_PATH="../target/aarch64-apple-darwin/$BUILD_MODE/libmls_rs_uniffi.dylib"
fi

if [ ! -f "$LIB_PATH" ]; then
  echo "Error: $LIB_PATH not found."
  exit 1
fi

echo "📦 Using library for binding generation: $LIB_PATH"

echo "🔄 Generating Swift bindings..."
# Use --no-format to disable auto-formatting and avoid swiftformat dependency
cargo run -p uniffi-bindgen -- generate --library "$LIB_PATH" --language swift --out-dir swift/bindings --no-format

# echo "🔧 Fixing Swift Error enum naming conflicts..."
# Only rename the public Error enum to MLSError to avoid Swift.Error conflicts
# sed -i '' 's/^public enum Error {/public enum MLSError {/g' swift/bindings/mls_rs_uniffi.swift
# sed -i '' 's/FfiConverterTypeError/FfiConverterTypeMLSError/g' swift/bindings/mls_rs_uniffi.swift
# sed -i '' 's/typealias SwiftType = Error/typealias SwiftType = MLSError/g' swift/bindings/mls_rs_uniffi.swift
# sed -i '' 's/throws -> Error {/throws -> MLSError {/g' swift/bindings/mls_rs_uniffi.swift
# sed -i '' 's/(_ value: Error,/(_ value: MLSError,/g' swift/bindings/mls_rs_uniffi.swift
# sed -i '' 's/extension Error: Equatable, Hashable {}/extension MLSError: Equatable, Hashable {}/g' swift/bindings/mls_rs_uniffi.swift
# sed -i '' 's/extension Error: Swift\.Error {}/extension MLSError: Swift.Error {}/g' swift/bindings/mls_rs_uniffi.swift
# sed -i '' '/^extension Error: Error { }$/d' swift/bindings/mls_rs_uniffi.swift
# sed -i '' '/^extension MLSError: Equatable, Hashable {}$/a\
# extension MLSError: Swift.Error {}' swift/bindings/mls_rs_uniffi.swift

echo "🔧 Fixing Swift Error naming conflicts in generated bindings..."
# Remove the problematic line that causes naming conflict
sed -i '' '/^extension Error: Error { }$/d' swift/bindings/mls_rs_uniffi.swift

# Add proper Error protocol conformance instead
sed -i '' '/^extension Error: Equatable, Hashable {}$/a\
extension Error: Swift.Error {}' swift/bindings/mls_rs_uniffi.swift

echo "✅ Swift bindings generated and fixed in swift/bindings"
echo "🎯 Build mode: $BUILD_MODE"

if [ "$IOS_BUILD" = true ]; then
    # Create Swift Package Manager package (no XCFramework)
    echo "📦 Creating Swift Package..."
    rm -rf swift/MLSRsUniFFI
    mkdir -p swift/MLSRsUniFFI/Sources/MLSRsUniFFI

    # Create Package.swift for SPM package
    cat > swift/MLSRsUniFFI/Package.swift << 'EOF'
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
EOF

    # Copy Swift bindings to package
    cp swift/bindings/mls_rs_uniffi.swift swift/MLSRsUniFFI/Sources/MLSRsUniFFI/

    echo "🎯 Swift Package created: swift/MLSRsUniFFI/"
    echo "📋 Integration files ready for iOS:"
    echo "   📦 Swift Package: swift/MLSRsUniFFI/"
    echo "   📄 Swift bindings: swift/MLSRsUniFFI/Sources/MLSRsUniFFI/mls_rs_uniffi.swift"
    echo ""
    echo "📝 To integrate into your iOS project:"
    echo "   1. Copy the swift/MLSRsUniFFI/ folder to your project"
    echo "   2. Add it as a local Swift Package in Xcode"
    echo "   3. Import MLSRsUniFFI in your Swift files"
else
    # Copy macOS library to bindings directory for easy access
    cp "$LIB_PATH" swift/bindings/
    echo "📦 macOS library copied to swift/bindings/ for convenience"
    echo "📁 Library location: $LIB_PATH"
fi