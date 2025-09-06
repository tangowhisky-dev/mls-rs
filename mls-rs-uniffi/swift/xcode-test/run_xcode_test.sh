#!/bin/bash

# Xcode Command Line Test for MLS Swift Bindings
# This script compiles and runs a Swift test program using Xcode's tools

set -e

echo "🔨 Xcode Command Line Test for MLS Swift Bindings"
echo "=================================================="

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINDINGS_DIR="$(dirname "$SCRIPT_DIR")"
BINDINGS_FILES_DIR="$BINDINGS_DIR/bindings"
MLS_ROOT_DIR="$(dirname "$BINDINGS_DIR")"

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check if Xcode command line tools are installed
if ! command -v swiftc &> /dev/null; then
    echo "❌ Swift compiler (swiftc) not found. Please install Xcode command line tools:"
    echo "   xcode-select --install"
    exit 1
fi

echo "   ✅ Swift compiler found: $(swiftc --version | head -n 1)"

# Check if bindings are generated
if [ ! -f "$BINDINGS_FILES_DIR/mls_rs_uniffi.swift" ]; then
    echo "❌ Generated bindings not found. Running generate_swift_bindings.sh to create them..."
    cd "$MLS_ROOT_DIR"
    ./generate_swift_bindings.sh
    cd "$SCRIPT_DIR"
    
    if [ ! -f "$BINDINGS_FILES_DIR/mls_rs_uniffi.swift" ]; then
        echo "❌ Failed to generate Swift bindings."
        exit 1
    fi
fi

echo "   ✅ Generated Swift bindings found"

# Check if the dynamic library exists
DYLIB_PATH="$MLS_ROOT_DIR/../target/aarch64-apple-darwin/debug/libmls_rs_uniffi.dylib"
if [ ! -f "$DYLIB_PATH" ]; then
    echo "❌ macOS library not found. Running generate_swift_bindings.sh to build library..."
    cd "$MLS_ROOT_DIR"
    ./generate_swift_bindings.sh
    cd "$SCRIPT_DIR"
    
    if [ ! -f "$DYLIB_PATH" ]; then
        echo "❌ Failed to generate macOS library."
        exit 1
    fi
fi

echo "   ✅ macOS library found"

# Create temporary directory for compilation
TEMP_DIR=$(mktemp -d)
echo "📁 Using temporary directory: $TEMP_DIR"

# Copy necessary files
echo "📋 Copying files for compilation..."
cp "$BINDINGS_FILES_DIR/mls_rs_uniffi.swift" "$TEMP_DIR/"
cp "$BINDINGS_FILES_DIR/mls_rs_uniffiFFI.h" "$TEMP_DIR/"
cp "$BINDINGS_FILES_DIR/mls_rs_uniffiFFI.modulemap" "$TEMP_DIR/"
cp "$SCRIPT_DIR/main.swift" "$TEMP_DIR/"
cp "$SCRIPT_DIR/client_tests.swift" "$TEMP_DIR/"
cp "$SCRIPT_DIR/group_tests.swift" "$TEMP_DIR/"
cp "$SCRIPT_DIR/encryption_tests.swift" "$TEMP_DIR/"
cp "$SCRIPT_DIR/comprehensive_api_tests.swift" "$TEMP_DIR/"
cp "$SCRIPT_DIR/advanced_tests.swift" "$TEMP_DIR/"
cp "$SCRIPT_DIR/error_and_storage_tests.swift" "$TEMP_DIR/"
cp "$SCRIPT_DIR/groupstate_storage_tests.swift" "$TEMP_DIR/"
cp "$DYLIB_PATH" "$TEMP_DIR/libmls_rs_uniffi.dylib"

# Fix the Swift Error naming conflict in the generated bindings
echo "🔧 Fixing Swift Error naming conflicts..."
# Remove the problematic line that causes naming conflict
sed -i '' '/^extension Error: Error { }$/d' "$TEMP_DIR/mls_rs_uniffi.swift"
# Add proper Error protocol conformance instead
sed -i '' '/^extension Error: Equatable, Hashable {}$/a\
extension Error: Swift.Error {}' "$TEMP_DIR/mls_rs_uniffi.swift"

echo "🔨 Compiling Swift test program..."
cd "$TEMP_DIR"

# Compile the Swift program with the MLS library
# Use the generated FFI header directly without creating a bridging header
swiftc -o mls_test \
    -I . \
    -L . \
    -lmls_rs_uniffi \
    -import-objc-header mls_rs_uniffiFFI.h \
    mls_rs_uniffi.swift main.swift client_tests.swift group_tests.swift encryption_tests.swift comprehensive_api_tests.swift advanced_tests.swift error_and_storage_tests.swift groupstate_storage_tests.swift

echo "✅ Compilation successful!"

# Run the test
echo ""
echo "🚀 Running the test program..."
echo "==============================="

# Set the library path so the executable can find the dynamic library
export DYLD_LIBRARY_PATH=".:${DYLD_LIBRARY_PATH:-}"

# Run the test
set +e
./mls_test
TEST_EXIT_CODE=$?
set -e

# Clean up
echo ""
echo "🧹 Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

# Report results
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "🎉 XCODE COMMAND LINE TEST PASSED!"
    echo "=================================="
    echo ""
    echo "✅ The MLS Swift bindings work correctly with Xcode tools"
    echo "✅ All functions are accessible and working as expected"
    echo "✅ macOS library linking is working properly"
    echo "✅ FFI interface is functioning correctly"
    echo ""
    echo "🚀 Your bindings are ready for integration into iOS/macOS Xcode projects!"
    echo ""
    echo "📝 Next steps:"
    echo "   1. See swift/README.md for integration instructions"
    echo "   2. Use the generated bindings from swift/bindings/ folder"
    echo "   3. Copy the swift/bindings/ files to your Xcode project"
    echo "   4. Configure build settings as described in the documentation"
else
    echo ""
    echo "❌ XCODE COMMAND LINE TEST FAILED!"
    echo "================================="
    echo ""
    echo "The test program failed with exit code $TEST_EXIT_CODE"
    echo "Please check the output above for error details."
    echo ""
    exit $TEST_EXIT_CODE
fi
