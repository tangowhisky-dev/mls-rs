#!/bin/bash
# Script to generate Swift bindings and an SPM package for mls-rs-uniffi using UniFFI
# Usage: ./generate_swift_bindings.sh [--release] [--ios]
#   --release: Build and use release version of the library (default: debug)
#   --ios: Build for iOS targets and create an XCFramework-backed Swift Package

set -euo pipefail

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
            echo "Unknown argument: $1" >&2
            echo "Usage: $0 [--release] [--ios]" >&2
            exit 1
            ;;
    esac
done

TARGET_DIR="../target"
BUILD_DIR="swift/bindings"
PACKAGE_DIR="swift/MLSRsUniFFI"

mkdir -p "$BUILD_DIR"

if [ "$IOS_BUILD" = true ]; then
    echo "🛠️ Building mls-rs-uniffi $BUILD_MODE for iOS (static libs) ..."

    # Environment for iOS cross-compilation with vendored OpenSSL
    export OPENSSL_STATIC=1
    export OPENSSL_VENDORED=1
    export IPHONEOS_DEPLOYMENT_TARGET=17.0

    echo "🔧 Config: OPENSSL_STATIC=$OPENSSL_STATIC, OPENSSL_VENDORED=$OPENSSL_VENDORED, IPHONEOS_DEPLOYMENT_TARGET=$IPHONEOS_DEPLOYMENT_TARGET"

    # Clean previous iOS artifacts
    cargo clean --target aarch64-apple-ios || true
    cargo clean --target aarch64-apple-ios-sim || true

    # Build static libraries for device and simulator
    echo "📱 Building staticlib for device (aarch64-apple-ios) ..."
    cargo build --target aarch64-apple-ios -p mls-rs-uniffi --features "mls-rs-crypto-openssl/vendored" $CARGO_FLAGS
    echo "�️ Building staticlib for simulator (aarch64-apple-ios-sim) ..."
    cargo build --target aarch64-apple-ios-sim -p mls-rs-uniffi --features "mls-rs-crypto-openssl/vendored" $CARGO_FLAGS

    # Paths to built artifacts (absolute)
    DEV_LIB="$(cd "$TARGET_DIR/aarch64-apple-ios/$BUILD_MODE" && pwd)/libmls_rs_uniffi.a"
    SIM_LIB="$(cd "$TARGET_DIR/aarch64-apple-ios-sim/$BUILD_MODE" && pwd)/libmls_rs_uniffi.a"

    # Fallback to dylib if staticlib not produced (older toolchains)
    if [ ! -f "$DEV_LIB" ]; then DEV_LIB="$TARGET_DIR/aarch64-apple-ios/$BUILD_MODE/libmls_rs_uniffi.dylib"; fi
    if [ ! -f "$SIM_LIB" ]; then SIM_LIB="$TARGET_DIR/aarch64-apple-ios-sim/$BUILD_MODE/libmls_rs_uniffi.dylib"; fi

    if [ ! -f "$DEV_LIB" ] || [ ! -f "$SIM_LIB" ]; then
        echo "❌ Built libraries not found:"
        echo "   Device: $DEV_LIB"
        echo "   Simulator: $SIM_LIB"
        exit 70
    fi

    # Use device library for generating Swift bindings (symbol discovery only)
    LIB_PATH="${DEV_LIB/%\.a/.dylib}"
    if [ ! -f "$LIB_PATH" ]; then
        # If no dylib exists, still pass the staticlib - uniffi can work with header+udl symbols already compiled into crate
        LIB_PATH="$DEV_LIB"
    fi
else
    echo "🛠️ Building mls-rs-uniffi $BUILD_MODE dylib for macOS..."
    cargo build --target aarch64-apple-darwin -p mls-rs-uniffi $CARGO_FLAGS
    LIB_PATH="$TARGET_DIR/aarch64-apple-darwin/$BUILD_MODE/libmls_rs_uniffi.dylib"
fi

if [ ! -f "$LIB_PATH" ]; then
  echo "Error: $LIB_PATH not found." >&2
  exit 1
fi

echo "📦 Using library for binding generation: $LIB_PATH"

echo "🔄 Generating Swift bindings..."
cargo run -p uniffi-bindgen -- generate --library "$LIB_PATH" --language swift --out-dir "$BUILD_DIR" --no-format

echo "🔧 Patching Swift bindings for Error conformance..."
sed -i '' '/^extension Error: Error { }$/d' "$BUILD_DIR/mls_rs_uniffi.swift" || true
sed -i '' '/^extension Error: Equatable, Hashable {}$/a\
extension Error: Swift.Error {}' "$BUILD_DIR/mls_rs_uniffi.swift" || true

echo "✅ Swift bindings generated at $BUILD_DIR"
echo "🎯 Build mode: $BUILD_MODE"

if [ "$IOS_BUILD" = true ]; then
    echo "📦 Creating XCFramework and Swift Package..."
    rm -rf "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR/Sources/MLSRsUniFFI"
    mkdir -p "$PACKAGE_DIR/Sources/FFI/include"
    mkdir -p "$PACKAGE_DIR/Artifacts"

    # Copy Swift sources (public API) into the package target
    cp "$BUILD_DIR/mls_rs_uniffi.swift" "$PACKAGE_DIR/Sources/MLSRsUniFFI/"

    # Copy FFI headers and modulemap; keep the original module name `mls_rs_uniffiFFI` as expected by generated Swift
    cp "$BUILD_DIR/mls_rs_uniffiFFI.h" "$PACKAGE_DIR/Sources/FFI/include/"
    cp "$BUILD_DIR/mls_rs_uniffiFFI.modulemap" "$PACKAGE_DIR/Sources/FFI/include/module.modulemap"

        # Ensure the FFI target produces at least one object file; add a tiny C shim if no .c exists
        if [ ! -f "$PACKAGE_DIR/Sources/FFI/ffi_placeholder.c" ]; then
            cat > "$PACKAGE_DIR/Sources/FFI/ffi_placeholder.c" <<'CSRC'
// Minimal source to force Xcode/SwiftPM to build the FFI target and link headers-only module.
// This avoids "FFI.o not found" when the target previously contained only headers.
int mlsrs_uniffi_ffi_placeholder(void) { return 0; }
CSRC
        fi

    # Create fat XCFramework from device + simulator libs
        pushd "$PACKAGE_DIR/Artifacts" >/dev/null
        rm -rf MLSRsUniFFI.xcframework
        # Create XCFramework from static libraries with headers
            # Do not embed headers/module.modulemap inside the XCFramework to avoid duplicate module definitions.
            xcodebuild -create-xcframework \
                -library "$DEV_LIB" \
                -library "$SIM_LIB" \
                -output MLSRsUniFFI.xcframework
        popd >/dev/null

    # Create Package.swift that uses the XCFramework as a binary target plus a Swift target that depends on the FFI headers
    cat > "$PACKAGE_DIR/Package.swift" << 'EOF'
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
EOF

    # README
    cat > "$PACKAGE_DIR/README.md" << 'EOF'
# MLSRsUniFFI

Swift bindings for mls-rs cryptography library using UniFFI.

This package ships:
- Swift sources generated by UniFFI
- C FFI headers + modulemap (module name: mls_rs_uniffiFFI)
- An XCFramework containing the Rust static library for iOS device and simulator

## Local Integration

Add this folder as a local Swift Package to your Xcode workspace.

In your app target's Build Settings:
- Ensure "Enable Bitcode" is NO (for modern Xcode it is removed).
- Ensure "Other Linker Flags" contains: -lc++ -lz

Then in code:

```swift
import MLSRsUniFFI
```
EOF

    echo "🎯 Swift Package ready at $PACKAGE_DIR"
else
    # For macOS development, drop dylib next to bindings for quick testing
    cp "$LIB_PATH" "$BUILD_DIR/" || true
    echo "📦 macOS library copied to $BUILD_DIR"
fi