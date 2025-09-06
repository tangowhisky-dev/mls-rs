#!/bin/bash
# Script to generate Kotlin bindings for mls-rs-uniffi using UniFFI
# Usage: ./generate_kotlin_bindings.sh [--release]
#   --release: Build and use release version of the library (default: debug)

set -e

# Parse command line arguments
BUILD_MODE="debug"
CARGO_FLAGS=""

for arg in "$@"; do
    case $arg in
        --release)
            BUILD_MODE="release"
            CARGO_FLAGS="--release"
            shift
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [--release]"
            exit 1
            ;;
    esac
done

echo "🛠️ Building mls-rs-uniffi $BUILD_MODE dylib for macOS..."
cargo build --target aarch64-apple-darwin -p mls-rs-uniffi $CARGO_FLAGS

LIB_PATH="../target/aarch64-apple-darwin/$BUILD_MODE/libmls_rs_uniffi.dylib"
if [ ! -f "$LIB_PATH" ]; then
  echo "Error: $LIB_PATH not found."
  exit 1
fi

echo "📦 Using library: $LIB_PATH"

echo "🔄 Generating Kotlin bindings..."
cargo run -p uniffi-bindgen -- generate --library "$LIB_PATH" --language kotlin --out-dir kotlin/bindings

echo "✅ Kotlin bindings generated in kotlin/bindings"
echo "🎯 Build mode: $BUILD_MODE"
echo "📁 Library location: $LIB_PATH"

# Copy the dylib to the bindings directory for easy access
cp "$LIB_PATH" kotlin/bindings/
echo "📦 Library copied to kotlin/bindings/ for convenience"
