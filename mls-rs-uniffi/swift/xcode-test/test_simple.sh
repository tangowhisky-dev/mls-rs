#!/bin/bash

# Simple test script for quick MLS Swift binding validation
set -e

echo "🔍 Simple MLS Swift Bindings Test"
echo "================================="

# Get paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINDINGS_DIR="$(dirname "$SCRIPT_DIR")"
BINDINGS_FILES_DIR="$BINDINGS_DIR/bindings"
MLS_ROOT_DIR="$(dirname "$BINDINGS_DIR")"
DYLIB_PATH="$MLS_ROOT_DIR/../target/aarch64-apple-darwin/debug/libmls_rs_uniffi.dylib"

# Check prerequisites
if ! command -v swiftc &> /dev/null; then
    echo "❌ Swift compiler not found"
    exit 1
fi

if [ ! -f "$BINDINGS_FILES_DIR/mls_rs_uniffi.swift" ]; then
    echo "❌ Swift bindings not found"
    exit 1
fi

if [ ! -f "$DYLIB_PATH" ]; then
    echo "❌ Dynamic library not found"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Create a simple test program
TEMP_DIR=$(mktemp -d)
echo "📁 Using temporary directory: $TEMP_DIR"

# Copy files
cp "$BINDINGS_FILES_DIR/mls_rs_uniffi.swift" "$TEMP_DIR/"
cp "$BINDINGS_FILES_DIR/mls_rs_uniffiFFI.h" "$TEMP_DIR/"
cp "$BINDINGS_FILES_DIR/mls_rs_uniffiFFI.modulemap" "$TEMP_DIR/"
cp "$DYLIB_PATH" "$TEMP_DIR/libmls_rs_uniffi.dylib"

# Fix the Swift Error naming conflict in the generated bindings
echo "🔧 Fixing Swift Error naming conflicts..."
# Remove the problematic line that causes naming conflict
sed -i '' '/^extension Error: Error { }$/d' "$TEMP_DIR/mls_rs_uniffi.swift"
# Add proper Error protocol conformance instead
sed -i '' '/^extension Error: Equatable, Hashable {}$/a\
extension Error: Swift.Error {}' "$TEMP_DIR/mls_rs_uniffi.swift"

# Create simple test that works around the Error naming issue
cat > "$TEMP_DIR/simple_test.swift" << 'EOF'
import Foundation

// Simple test that verifies basic MLS functionality
@main
struct SimpleMLSTest {
    static func main() {
        print("🧪 Simple MLS Test")
        print("==================")

        print("1. Testing client config...")
        let config = clientConfigDefault()
        print("   ✅ Config created")
        
        print("2. Testing keypair generation...")
        do {
            let keypair = try generateSignatureKeypair(cipherSuite: CipherSuite.curve25519Aes128)
            print("   ✅ Keypair generated")
            
            print("3. Testing client creation...")
            let clientId = "test".data(using: .utf8)!
            let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
            print("   ✅ Client created")
            
            print("4. Testing group creation...")
            let _ = try client.createGroup(groupId: Optional<Data>.none)
            print("   ✅ Group created")
            
            print("\n🎉 ALL TESTS PASSED!")
            
        } catch {
            print("❌ Test failed with error")
            print("   Error details: \(error)")
            exit(1)
        }
    }
}
EOF

cd "$TEMP_DIR"

echo "🔨 Compiling simple test..."
swiftc -o simple_test \
    -I . \
    -L . \
    -lmls_rs_uniffi \
    -import-objc-header mls_rs_uniffiFFI.h \
    mls_rs_uniffi.swift simple_test.swift

echo "🚀 Running simple test..."
export DYLD_LIBRARY_PATH=".:${DYLD_LIBRARY_PATH:-}"
./simple_test

echo ""
echo "🧹 Cleaning up..."
rm -rf "$TEMP_DIR"

echo "✅ Simple test completed successfully!"
