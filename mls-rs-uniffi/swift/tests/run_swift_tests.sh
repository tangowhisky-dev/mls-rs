#!/bin/bash

# MLS Swift Package Tests Runner
# This script automatically copies generated bindings and runs Swift package tests
# Usage: ./run_swift_tests.sh [--release]
#   --release: Use release version of the library (default: debug)

set -e

# Parse command line arguments
BUILD_MODE="debug"
GENERATION_FLAGS=""

for arg in "$@"; do
    case $arg in
        --release)
            BUILD_MODE="release"
            GENERATION_FLAGS="--release"
            shift
            ;;
        *)
            echo "Unknown argument: $arg"
            echo "Usage: $0 [--release]"
            exit 1
            ;;
    esac
done

echo "🧪 MLS Swift Package Tests Runner ($BUILD_MODE mode)"
echo "=================================="

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UNIFFI_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
BINDINGS_SRC="$UNIFFI_DIR/swift/bindings"
BINDINGS_DEST="$SCRIPT_DIR/Sources/MLSSwiftBindings"
DYLIB_SRC="$UNIFFI_DIR/../target/aarch64-apple-darwin/$BUILD_MODE/libmls_rs_uniffi.dylib"

echo "📁 Working from: $SCRIPT_DIR"
echo "📂 Bindings source: $BINDINGS_SRC"
echo "📂 Bindings destination: $BINDINGS_DEST"
echo "📦 Library source: $DYLIB_SRC ($BUILD_MODE)"

# Check prerequisites
echo ""
echo "🔍 Checking prerequisites..."

if ! command -v swift &> /dev/null; then
    echo "❌ Swift compiler not found. Install Xcode command line tools:"
    echo "   xcode-select --install"
    exit 1
fi
echo "✅ Swift compiler found: $(swift --version | head -n1)"

# Check if bindings exist, generate if needed
if [ ! -d "$BINDINGS_SRC" ] || [ ! -f "$BINDINGS_SRC/mls_rs_uniffi.swift" ]; then
    echo "🔄 Generated bindings not found. Running generation script..."
    cd "$(dirname "$UNIFFI_DIR")/mls-rs-uniffi"
    if [ -f "generate_swift_bindings.sh" ]; then
        ./generate_swift_bindings.sh $GENERATION_FLAGS
    else
        echo "❌ generate_swift_bindings.sh not found"
        exit 1
    fi
    cd "$SCRIPT_DIR"
else
    echo "✅ Generated Swift bindings found"
fi

# Check if dylib exists
if [ ! -f "$DYLIB_SRC" ]; then
    echo "❌ Dynamic library not found at: $DYLIB_SRC"
    echo "🔄 Building MLS library ($BUILD_MODE mode)..."
    cd "$(dirname "$UNIFFI_DIR")/mls-rs-uniffi"
    if [ "$BUILD_MODE" = "release" ]; then
        cargo build --target aarch64-apple-darwin --release
    else
        cargo build --target aarch64-apple-darwin
    fi
    cd "$SCRIPT_DIR"
    
    if [ ! -f "$DYLIB_SRC" ]; then
        echo "❌ Failed to build dynamic library"
        exit 1
    fi
fi
echo "✅ Dynamic library found ($BUILD_MODE)"

# Create destination directory
echo ""
echo "📋 Preparing Swift package structure..."
mkdir -p "$BINDINGS_DEST"

# Copy generated bindings
echo "📄 Copying Swift bindings..."
cp "$BINDINGS_SRC/mls_rs_uniffi.swift" "$BINDINGS_DEST/"
cp "$BINDINGS_SRC/mls_rs_uniffiFFI.h" "$BINDINGS_DEST/"
cp "$BINDINGS_SRC/mls_rs_uniffiFFI.modulemap" "$BINDINGS_DEST/"

# Copy dynamic library
echo "📦 Copying dynamic library..."
cp "$DYLIB_SRC" "$BINDINGS_DEST/"

# Create module.modulemap if it doesn't exist
if [ ! -f "$BINDINGS_DEST/module.modulemap" ]; then
    echo "📝 Creating module.modulemap..."
    cat > "$BINDINGS_DEST/module.modulemap" << 'EOF'
module mls_rs_uniffiFFI {
    header "mls_rs_uniffiFFI.h"
    export *
}
EOF
fi

echo "✅ All files copied successfully"

# Verify files are in place
echo ""
echo "🔍 Verifying copied files..."
REQUIRED_FILES=(
    "mls_rs_uniffi.swift"
    "mls_rs_uniffiFFI.h"
    "mls_rs_uniffiFFI.modulemap"
    "libmls_rs_uniffi.dylib"
    "module.modulemap"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$BINDINGS_DEST/$file" ]; then
        echo "✅ $file"
    else
        echo "❌ Missing: $file"
        exit 1
    fi
done

echo ""
echo "🚀 Running Swift package tests..."
echo "================================="

# Run the tests
if swift test; then
    echo ""
    echo "🎉 SUCCESS!"
    echo "==========="
    echo "✅ All Swift package tests passed!"
    echo "✅ MLS Swift bindings are working correctly"
    echo "✅ Package structure is properly configured"
    echo ""
    echo "📝 Next steps:"
    echo "   - Your Swift package tests are now working"
    echo "   - Bindings and library are properly linked"
    echo "   - You can integrate these bindings into iOS/macOS projects"
else
    echo ""
    echo "❌ FAILURE!"
    echo "==========="
    echo "❌ Swift package tests failed"
    echo "📋 Check the error output above for details"
    exit 1
fi
