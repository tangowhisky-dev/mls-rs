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
    cargo clean --target x86_64-apple-ios

    # Build for iOS device (arm64)
    echo "📱 Building for iOS device (arm64)..."
    cargo build --target aarch64-apple-ios -p mls-rs-uniffi --features "mls-rs-crypto-openssl/vendored" $CARGO_FLAGS

    # Build for iOS simulator (arm64)
    echo "📱 Building for iOS simulator (arm64)..."
    cargo build --target aarch64-apple-ios-sim -p mls-rs-uniffi --features "mls-rs-crypto-openssl/vendored" $CARGO_FLAGS

    # Build for iOS simulator (x86_64) - for Intel Macs
    echo "📱 Building for iOS simulator (x86_64)..."
    cargo build --target x86_64-apple-ios -p mls-rs-uniffi --features "mls-rs-crypto-openssl/vendored" $CARGO_FLAGS

    # Create universal simulator library
    echo "� Creating universal simulator library..."
    mkdir -p ../target/ios-simulator-universal/$BUILD_MODE
    lipo -create \
        ../target/aarch64-apple-ios-sim/$BUILD_MODE/libmls_rs_uniffi.dylib \
        ../target/x86_64-apple-ios/$BUILD_MODE/libmls_rs_uniffi.dylib \
        -output ../target/ios-simulator-universal/$BUILD_MODE/libmls_rs_uniffi.dylib

    # Use iOS device library for binding generation
    LIB_PATH="../target/aarch64-apple-ios/$BUILD_MODE/libmls_rs_uniffi.dylib"

    echo "📦 iOS libraries created:"
    echo "   📱 Device: ../target/aarch64-apple-ios/$BUILD_MODE/libmls_rs_uniffi.dylib"
    echo "   🖥️ Simulator: ../target/ios-simulator-universal/$BUILD_MODE/libmls_rs_uniffi.dylib"
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
# Suppress swiftformat warning if not installed
cargo run -p uniffi-bindgen -- generate --library "$LIB_PATH" --language swift --out-dir swift/bindings 2> >(grep -v "swiftformat" >&2)

echo "🔧 Fixing Swift Error enum naming conflicts..."
# Only rename the public Error enum to MLSError to avoid Swift.Error conflicts
sed -i '' 's/^public enum Error {/public enum MLSError {/g' swift/bindings/mls_rs_uniffi.swift
sed -i '' 's/FfiConverterTypeError/FfiConverterTypeMLSError/g' swift/bindings/mls_rs_uniffi.swift
sed -i '' 's/typealias SwiftType = Error/typealias SwiftType = MLSError/g' swift/bindings/mls_rs_uniffi.swift
sed -i '' 's/throws -> Error {/throws -> MLSError {/g' swift/bindings/mls_rs_uniffi.swift
sed -i '' 's/(_ value: Error,/(_ value: MLSError,/g' swift/bindings/mls_rs_uniffi.swift
sed -i '' 's/extension Error: Equatable, Hashable {}/extension MLSError: Equatable, Hashable {}/g' swift/bindings/mls_rs_uniffi.swift
sed -i '' 's/extension Error: Swift\.Error {}/extension MLSError: Swift.Error {}/g' swift/bindings/mls_rs_uniffi.swift
sed -i '' '/^extension Error: Error { }$/d' swift/bindings/mls_rs_uniffi.swift
sed -i '' '/^extension MLSError: Equatable, Hashable {}$/a\
extension MLSError: Swift.Error {}' swift/bindings/mls_rs_uniffi.swift

echo "✅ Swift bindings generated and fixed in swift/bindings"
echo "🎯 Build mode: $BUILD_MODE"

if [ "$IOS_BUILD" = true ]; then
    # Copy iOS libraries to bindings directory
    mkdir -p swift/bindings/ios-device
    mkdir -p swift/bindings/ios-simulator

    cp "../target/aarch64-apple-ios/$BUILD_MODE/libmls_rs_uniffi.dylib" swift/bindings/ios-device/
    cp "../target/ios-simulator-universal/$BUILD_MODE/libmls_rs_uniffi.dylib" swift/bindings/ios-simulator/

    echo "📦 iOS libraries copied to swift/bindings/:"
    echo "   � Device: swift/bindings/ios-device/libmls_rs_uniffi.dylib"
    echo "   🖥️ Simulator: swift/bindings/ios-simulator/libmls_rs_uniffi.dylib"

    # Create Swift Package with binary targets
    echo "📦 Creating Swift Package..."
    rm -rf swift/MLSRsUniFFI
    mkdir -p swift/MLSRsUniFFI/Sources/MLSRsUniFFI

    # Create Package.swift with binary targets
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
            dependencies: ["MLSRsUniFFIBinary"]
        ),
        .binaryTarget(
            name: "MLSRsUniFFIBinary",
            path: "MLSRsUniFFI.xcframework"
        )
    ]
)
EOF

    # Create XCFramework for the package
    echo "🏗️ Creating XCFramework..."
    rm -rf swift/MLSRsUniFFI/MLSRsUniFFI.xcframework

    # Copy headers to separate directories for each platform
    mkdir -p swift/bindings/ios-device-headers
    mkdir -p swift/bindings/ios-simulator-headers
    cp swift/bindings/mls_rs_uniffiFFI.h swift/bindings/ios-device-headers/
    cp swift/bindings/mls_rs_uniffiFFI.modulemap swift/bindings/ios-device-headers/
    cp swift/bindings/mls_rs_uniffiFFI.h swift/bindings/ios-simulator-headers/
    cp swift/bindings/mls_rs_uniffiFFI.modulemap swift/bindings/ios-simulator-headers/

    xcodebuild -create-xcframework \
        -library swift/bindings/ios-device/libmls_rs_uniffi.dylib \
        -headers swift/bindings/ios-device-headers \
        -library swift/bindings/ios-simulator/libmls_rs_uniffi.dylib \
        -headers swift/bindings/ios-simulator-headers \
        -output swift/MLSRsUniFFI/MLSRsUniFFI.xcframework

    # Clean up temporary header directories
    rm -rf swift/bindings/ios-device-headers
    rm -rf swift/bindings/ios-simulator-headers

    # Copy Swift bindings to package
    cp swift/bindings/mls_rs_uniffi.swift swift/MLSRsUniFFI/Sources/MLSRsUniFFI/

    echo "🎯 Swift Package created: swift/MLSRsUniFFI/"
    echo "📋 Integration files ready for iOS:"
    echo "   📦 Swift Package: swift/MLSRsUniFFI/"
    echo "   📄 Swift bindings: swift/MLSRsUniFFI/Sources/MLSRsUniFFI/mls_rs_uniffi.swift"
    echo "   🏗️ XCFramework: swift/MLSRsUniFFI/MLSRsUniFFI.xcframework"
else
    # Copy macOS library to bindings directory for easy access
    cp "$LIB_PATH" swift/bindings/
    echo "📦 macOS library copied to swift/bindings/ for convenience"
    echo "📁 Library location: $LIB_PATH"
fi

set -e

# Parse command line arguments
BUILD_MODE="debug"
CARGO_FLAGS=""
IOS_BUILD=false

for arg in "$@"; do
    case $arg in
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
            echo "Unknown argument: $arg"
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
    
    # Set iOS deployment target to match Khudi Chat project (iOS 17.0)
    export IPHONEOS_DEPLOYMENT_TARGET=17.0
    export IOS_DEPLOYMENT_TARGET=17.0
    
    # Set iOS SDK paths
    IOS_SDK_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk"
    IOS_SIM_SDK_PATH="/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk"
    
    echo "🔧 Cross-compilation configuration:"
    echo "   OPENSSL_STATIC: $OPENSSL_STATIC"
    echo "   OPENSSL_VENDORED: $OPENSSL_VENDORED"
    echo "   IPHONEOS_DEPLOYMENT_TARGET: $IPHONEOS_DEPLOYMENT_TARGET"
    echo "   iOS SDK: $IOS_SDK_PATH"
    echo "   iOS Simulator SDK: $IOS_SIM_SDK_PATH"
    
    # Clean previous build artifacts for iOS
    echo "🧹 Cleaning previous iOS build artifacts..."
    cargo clean --target aarch64-apple-ios
    cargo clean --target aarch64-apple-ios-sim  
    cargo clean --target x86_64-apple-ios
    
    # Build for iOS device (arm64)
    echo "📱 Building for iOS device (arm64)..."
    CC_aarch64_apple_ios=clang \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    cargo build --target aarch64-apple-ios -p mls-rs-uniffi --features "mls-rs-crypto-openssl/vendored" $CARGO_FLAGS
    
    # Build for iOS simulator (arm64)
    echo "📱 Building for iOS simulator (arm64)..."
    CC_aarch64_apple_ios_sim=clang \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    cargo build --target aarch64-apple-ios-sim -p mls-rs-uniffi --features "mls-rs-crypto-openssl/vendored" $CARGO_FLAGS
    
    # Build for iOS simulator (x86_64) - for Intel Macs
    echo "📱 Building for iOS simulator (x86_64)..."
    CC_x86_64_apple_ios=clang \
    IPHONEOS_DEPLOYMENT_TARGET=17.0 \
    cargo build --target x86_64-apple-ios -p mls-rs-uniffi --features "mls-rs-crypto-openssl/vendored" $CARGO_FLAGS
    
    # Create universal simulator library
    echo "🔗 Creating universal simulator library..."
    mkdir -p ../target/ios-simulator-universal/$BUILD_MODE
    lipo -create \
        ../target/aarch64-apple-ios-sim/$BUILD_MODE/libmls_rs_uniffi.dylib \
        ../target/x86_64-apple-ios/$BUILD_MODE/libmls_rs_uniffi.dylib \
        -output ../target/ios-simulator-universal/$BUILD_MODE/libmls_rs_uniffi.dylib
    
    # Use iOS device library for binding generation
    LIB_PATH="../target/aarch64-apple-ios/$BUILD_MODE/libmls_rs_uniffi.dylib"
    
    echo "📦 iOS libraries created:"
    echo "   📱 Device: ../target/aarch64-apple-ios/$BUILD_MODE/libmls_rs_uniffi.dylib"
    echo "   🖥️ Simulator: ../target/ios-simulator-universal/$BUILD_MODE/libmls_rs_uniffi.dylib"
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
# Suppress swiftformat warning if not installed
cargo run -p uniffi-bindgen -- generate --library "$LIB_PATH" --language swift --out-dir swift/bindings 2> >(grep -v "swiftformat" >&2)

echo "🔧 Fixing Swift Error enum naming conflicts..."
# Only rename the public Error enum to MLSError to avoid Swift.Error conflicts  
sed -i '' 's/^public enum Error {/public enum MLSError {/g' swift/bindings/mls_rs_uniffi.swift
# Update all FfiConverterTypeError references to FfiConverterTypeMLSError
sed -i '' 's/FfiConverterTypeError/FfiConverterTypeMLSError/g' swift/bindings/mls_rs_uniffi.swift
# Update Error type references in function signatures to MLSError
sed -i '' 's/typealias SwiftType = Error/typealias SwiftType = MLSError/g' swift/bindings/mls_rs_uniffi.swift
# Fix function signatures that use Error as return type or parameter
sed -i '' 's/throws -> Error {/throws -> MLSError {/g' swift/bindings/mls_rs_uniffi.swift
sed -i '' 's/(_ value: Error,/(_ value: MLSError,/g' swift/bindings/mls_rs_uniffi.swift
# Fix extension declarations and remove problematic Error: Error extension
sed -i '' 's/extension Error: Equatable, Hashable {}/extension MLSError: Equatable, Hashable {}/g' swift/bindings/mls_rs_uniffi.swift
sed -i '' 's/extension Error: Swift\.Error {}/extension MLSError: Swift.Error {}/g' swift/bindings/mls_rs_uniffi.swift
sed -i '' '/^extension Error: Error { }$/d' swift/bindings/mls_rs_uniffi.swift
# Add Swift.Error conformance to the MLSError enum
sed -i '' '/^extension MLSError: Equatable, Hashable {}$/a\
extension MLSError: Swift.Error {}' swift/bindings/mls_rs_uniffi.swift

echo "✅ Swift bindings generated and fixed in swift/bindings"
echo "🎯 Build mode: $BUILD_MODE"

if [ "$IOS_BUILD" = true ]; then
    # Copy iOS libraries to bindings directory
    mkdir -p swift/bindings/ios-device
    mkdir -p swift/bindings/ios-simulator
    
    cp "../target/aarch64-apple-ios/$BUILD_MODE/libmls_rs_uniffi.dylib" swift/bindings/ios-device/
    cp "../target/ios-simulator-universal/$BUILD_MODE/libmls_rs_uniffi.dylib" swift/bindings/ios-simulator/
    
    echo "📦 iOS libraries copied to swift/bindings/:"
    echo "   📱 Device: swift/bindings/ios-device/libmls_rs_uniffi.dylib"
    echo "   🖥️ Simulator: swift/bindings/ios-simulator/libmls_rs_uniffi.dylib"
    
    # Create Swift Package (no XCFramework)
    echo "📦 Creating Swift Package..."
    rm -rf swift/MLSRsUniFFI
    mkdir -p swift/MLSRsUniFFI/Sources/MLSRsUniFFI
    
    # Create Package.swift - simple target, no binary
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
        .target(name: "MLSRsUniFFI"),
    ]
)
EOF

    # Copy Swift bindings to package
    cp swift/bindings/mls_rs_uniffi.swift swift/MLSRsUniFFI/Sources/MLSRsUniFFI/
    
    echo "🎯 Swift Package created: swift/MLSRsUniFFI/"
    echo "📋 Integration files ready for iOS:"
    echo "   � Swift Package: swift/MLSRsUniFFI/"
    echo "   �📄 Swift bindings: swift/MLSRsUniFFI/Sources/MLSRsUniFFI/mls_rs_uniffi.swift"
    echo "   🏗️ XCFramework: swift/MLSRsUniFFI/MLSRsUniFFI.xcframework"
else
    # Copy macOS library to bindings directory for easy access
    cp "$LIB_PATH" swift/bindings/
    echo "📦 macOS library copied to swift/bindings/ for convenience"
    echo "📁 Library location: $LIB_PATH"
fi
