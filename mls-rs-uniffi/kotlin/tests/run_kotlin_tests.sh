#!/bin/bash
set -e

echo "🔧 Kotlin Test Runner for MLS Bindings"
echo "======================================"

# Parse command line arguments
BUILD_MODE="debug"
CIPHER_SUITE_ID=1
FORCE_REFRESH=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_MODE="release"
            shift
            ;;
        --force-refresh|-f)
            FORCE_REFRESH=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options] [cipher_suite_id]"
            echo "Options:"
            echo "  --release             Use release build of the library"
            echo "  --force-refresh, -f   Force refresh of all libraries and bindings"
            echo "  --help, -h            Show this help message"
            echo ""
            echo "Cipher Suite IDs:"
            echo "  1: Curve25519 AES-128 (baseline)"
            echo "  2: P-256 AES-128 (enterprise)"
            echo "  3: Curve25519 ChaCha (mobile)"
            echo "  4: Curve448 AES-256 (high security)"
            echo "  5: P-521 AES-256 (maximum security)"
            echo "  6: Curve448 ChaCha (high security mobile)"
            echo "  7: P-384 AES-256 (government)"
            exit 0
            ;;
        [1-7])
            CIPHER_SUITE_ID=$1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Display configuration
echo "🎯 Configuration:"
echo "  Build mode: $BUILD_MODE"
echo "  Cipher suite ID: $CIPHER_SUITE_ID"
echo "  Force refresh: $FORCE_REFRESH"

# Determine script location and project paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KOTLIN_TESTS_DIR="$SCRIPT_DIR"
UNIFFI_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BINDINGS_DIR="$UNIFFI_ROOT/bindings"

echo "📁 Project paths:"
echo "  Kotlin tests: $KOTLIN_TESTS_DIR"
echo "  UniFFI bindings: $BINDINGS_DIR"

# Check if Gradle wrapper exists, otherwise use system gradle
if [ -f "$KOTLIN_TESTS_DIR/gradlew" ]; then
    GRADLE_CMD="./gradlew"
    echo "🔧 Using Gradle wrapper"
else
    GRADLE_CMD="gradle"
    echo "🔧 Using system Gradle"
fi

# Verify prerequisites
echo "🔍 Verifying prerequisites..."

# Check if bindings exist, if not or force refresh, generate them
if [ ! -d "$BINDINGS_DIR" ] || [ "$FORCE_REFRESH" = true ]; then
    echo "📋 Generating Kotlin bindings..."
    cd "$UNIFFI_ROOT"
    
    if [ "$BUILD_MODE" = "release" ]; then
        ./generate_kotlin_bindings.sh --release
    else
        ./generate_kotlin_bindings.sh
    fi
    
    cd "$KOTLIN_TESTS_DIR"
    echo "✅ Kotlin bindings generated"
else
    echo "✅ Kotlin bindings found"
fi

# Check if bindings are copied to test structure
if [ ! -d "$KOTLIN_TESTS_DIR/src/main/kotlin/uniffi" ] || [ "$FORCE_REFRESH" = true ]; then
    echo "📋 Copying generated Kotlin bindings to test structure..."
    mkdir -p "$KOTLIN_TESTS_DIR/src/main/kotlin"
    rm -rf "$KOTLIN_TESTS_DIR/src/main/kotlin/uniffi" 2>/dev/null || true
    cp -r "$BINDINGS_DIR/uniffi" "$KOTLIN_TESTS_DIR/src/main/kotlin/"
    echo "✅ Kotlin bindings updated in test structure"
else
    echo "✅ Kotlin bindings found in test structure"
fi

# Check and copy native libraries (dylib files)
echo "📋 Copying native libraries to test resources..."
mkdir -p "$KOTLIN_TESTS_DIR/src/main/resources"

# If force refresh, remove existing libraries
if [ "$FORCE_REFRESH" = true ]; then
    echo "  🧹 Removing existing library files for refresh..."
    rm -f "$KOTLIN_TESTS_DIR/src/main/resources/"*.dylib 2>/dev/null || true
fi

# Copy all dylib files from bindings directory
DYLIB_COUNT=0
if [ -d "$BINDINGS_DIR" ]; then
    for dylib_file in "$BINDINGS_DIR"/*.dylib; do
        if [ -f "$dylib_file" ]; then
            echo "  📦 Copying $(basename "$dylib_file")..."
            cp "$dylib_file" "$KOTLIN_TESTS_DIR/src/main/resources/"
            DYLIB_COUNT=$((DYLIB_COUNT + 1))
        fi
    done
fi

if [ $DYLIB_COUNT -eq 0 ]; then
    echo "❌ Error: No .dylib files found in $BINDINGS_DIR"
    echo "Please run generate_kotlin_bindings.sh first"
    exit 1
fi

echo "✅ Copied $DYLIB_COUNT native libraries"

# Clean previous build if force refresh
if [ "$FORCE_REFRESH" = true ]; then
    echo "🧹 Cleaning previous build..."
    $GRADLE_CMD clean
fi

# Run tests with cipher suite configuration
echo "🧪 Running tests with cipher suite $CIPHER_SUITE_ID..."
$GRADLE_CMD test -Dmls.cipher.suite.id=$CIPHER_SUITE_ID

echo ""
echo "✅ Kotlin test run completed successfully!"
echo "🎯 Cipher suite $CIPHER_SUITE_ID ($BUILD_MODE mode) validation complete"
