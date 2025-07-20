#!/bin/bash

set -e

# Configuration
FRAMEWORK_NAME="MlsRsFFI"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BINDINGS_DIR="$SCRIPT_DIR/swift"
BUILD_DIR="$SCRIPT_DIR/build"
XCFRAMEWORK_PATH="$BINDINGS_DIR/$FRAMEWORK_NAME.xcframework"

# Build configuration
BUILD_TYPE="${1:-release}"

echo "Building XCFramework for MLS-RS..."
echo "Build type: $BUILD_TYPE"
echo "Project directory: $PROJECT_DIR"
echo "Bindings directory: $BINDINGS_DIR"

# Clean previous builds
rm -rf "$BUILD_DIR"
rm -rf "$XCFRAMEWORK_PATH"
mkdir -p "$BUILD_DIR"

# iOS targets to build
TARGETS=(
    "aarch64-apple-ios"              # iOS Device (ARM64)
)

# iOS Simulator targets to combine
SIMULATOR_TARGETS=(
    "aarch64-apple-ios-sim"          # iOS Simulator (ARM64)
    "x86_64-apple-ios"               # iOS Simulator (x86_64)
)

# macOS targets to combine
MACOS_TARGETS=(
    "aarch64-apple-darwin"           # macOS (ARM64)
    "x86_64-apple-darwin"            # macOS (x86_64)
)

# Build for each target
for TARGET in "${TARGETS[@]}"; do
    echo "Building for target: $TARGET"
    
    # Add target if not already installed
    rustup target add "$TARGET" || true
    
    # Build the static library
    cd "$PROJECT_DIR"
    if [ "$BUILD_TYPE" == "release" ]; then
        cargo build --target "$TARGET" --release
        LIB_PATH="../target/$TARGET/release/libmls_rs_uniffi.a"
    else
        cargo build --target "$TARGET"
        LIB_PATH="../target/$TARGET/debug/libmls_rs_uniffi.a"
    fi
    
    # Create framework structure
    FRAMEWORK_DIR="$BUILD_DIR/$TARGET/$FRAMEWORK_NAME.framework"
    mkdir -p "$FRAMEWORK_DIR/Headers"
    mkdir -p "$FRAMEWORK_DIR/Modules"
    
    # Copy the static library
    cp "$LIB_PATH" "$FRAMEWORK_DIR/$FRAMEWORK_NAME"
    
    # Generate Swift bindings using uniffi-bindgen
    SWIFT_OUT_DIR="$BUILD_DIR/$TARGET/swift"
    mkdir -p "$SWIFT_OUT_DIR"
    
    cd "$PROJECT_DIR"
    cargo run --manifest-path uniffi-bindgen/Cargo.toml -- generate \
        --library "$LIB_PATH" \
        --language swift \
        --out-dir "$SWIFT_OUT_DIR"
    
    # Copy Swift files to framework if they exist
    if [ -d "$SWIFT_OUT_DIR" ]; then
        find "$SWIFT_OUT_DIR" -name "*.swift" -exec cp {} "$BINDINGS_DIR/Sources/MlsRs/" \;
        find "$SWIFT_OUT_DIR" -name "*.h" -exec cp {} "$FRAMEWORK_DIR/Headers/" \;
        
        # Create module map
        if [ -f "$SWIFT_OUT_DIR/mls_rs_uniffiFFI.h" ]; then
            cat > "$FRAMEWORK_DIR/Modules/module.modulemap" << EOF
framework module $FRAMEWORK_NAME {
    header "mls_rs_uniffiFFI.h"
    export *
}
EOF
        fi
    fi
    
    # Create Info.plist
    cat > "$FRAMEWORK_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.amazon.mls-rs.$FRAMEWORK_NAME</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>0.7.0</string>
    <key>CFBundleVersion</key>
    <string>0.7.0</string>
    <key>MinimumOSVersion</key>
    <string>17.0</string>
</dict>
</plist>
EOF
    
    echo "Completed build for $TARGET"
done

# Build and combine iOS Simulator targets
echo "Building iOS Simulator targets..."
SIMULATOR_LIBS=()
for TARGET in "${SIMULATOR_TARGETS[@]}"; do
    echo "Building for simulator target: $TARGET"
    
    # Add target if not already installed
    rustup target add "$TARGET" || true
    
    # Build the static library
    cd "$PROJECT_DIR"
    if [ "$BUILD_TYPE" == "release" ]; then
        cargo build --target "$TARGET" --release
        SIMULATOR_LIBS+=("../target/$TARGET/release/libmls_rs_uniffi.a")
    else
        cargo build --target "$TARGET"
        SIMULATOR_LIBS+=("../target/$TARGET/debug/libmls_rs_uniffi.a")
    fi
done

# Create combined iOS Simulator framework
if [ ${#SIMULATOR_LIBS[@]} -gt 0 ]; then
    echo "Creating combined iOS Simulator framework..."
    
    TARGET="ios-simulator"
    FRAMEWORK_DIR="$BUILD_DIR/$TARGET/$FRAMEWORK_NAME.framework"
    mkdir -p "$FRAMEWORK_DIR/Headers"
    mkdir -p "$FRAMEWORK_DIR/Modules"
    
    # Combine simulator libraries using lipo
    COMBINED_LIB="$BUILD_DIR/$TARGET/libmls_rs_uniffi.a"
    lipo -create "${SIMULATOR_LIBS[@]}" -output "$COMBINED_LIB"
    
    # Copy the combined library
    cp "$COMBINED_LIB" "$FRAMEWORK_DIR/$FRAMEWORK_NAME"
    
    # Generate Swift bindings using the first simulator library (they should be identical)
    SWIFT_OUT_DIR="$BUILD_DIR/$TARGET/swift"
    mkdir -p "$SWIFT_OUT_DIR"
    
    cd "$PROJECT_DIR"
    cargo run --manifest-path uniffi-bindgen/Cargo.toml -- generate \
        --library "${SIMULATOR_LIBS[0]}" \
        --language swift \
        --out-dir "$SWIFT_OUT_DIR"
    
    # Copy Swift files to framework if they exist
    if [ -d "$SWIFT_OUT_DIR" ]; then
        find "$SWIFT_OUT_DIR" -name "*.swift" -exec cp {} "$BINDINGS_DIR/Sources/MlsRs/" \;
        find "$SWIFT_OUT_DIR" -name "*.h" -exec cp {} "$FRAMEWORK_DIR/Headers/" \;
        
        # Create module map
        if [ -f "$SWIFT_OUT_DIR/mls_rs_uniffiFFI.h" ]; then
            cat > "$FRAMEWORK_DIR/Modules/module.modulemap" << EOF
framework module $FRAMEWORK_NAME {
    header "mls_rs_uniffiFFI.h"
    export *
}
EOF
        fi
    fi
    
    # Create Info.plist
    cat > "$FRAMEWORK_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.amazon.mls-rs.$FRAMEWORK_NAME</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>0.7.0</string>
    <key>CFBundleVersion</key>
    <string>0.7.0</string>
    <key>MinimumOSVersion</key>
    <string>17.0</string>
</dict>
</plist>
EOF
    
    echo "Completed iOS Simulator framework"
fi

# Build and combine macOS targets
echo "Building macOS targets..."
MACOS_LIBS=()
for TARGET in "${MACOS_TARGETS[@]}"; do
    echo "Building for macOS target: $TARGET"
    
    # Add target if not already installed
    rustup target add "$TARGET" || true
    
    # Build the static library
    cd "$PROJECT_DIR"
    if [ "$BUILD_TYPE" == "release" ]; then
        cargo build --target "$TARGET" --release
        MACOS_LIBS+=("../target/$TARGET/release/libmls_rs_uniffi.a")
    else
        cargo build --target "$TARGET"
        MACOS_LIBS+=("../target/$TARGET/debug/libmls_rs_uniffi.a")
    fi
done

# Create combined macOS framework
if [ ${#MACOS_LIBS[@]} -gt 0 ]; then
    echo "Creating combined macOS framework..."
    
    TARGET="macos"
    FRAMEWORK_DIR="$BUILD_DIR/$TARGET/$FRAMEWORK_NAME.framework"
    mkdir -p "$FRAMEWORK_DIR/Headers"
    mkdir -p "$FRAMEWORK_DIR/Modules"
    
    # Combine macOS libraries using lipo
    COMBINED_LIB="$BUILD_DIR/$TARGET/libmls_rs_uniffi.a"
    lipo -create "${MACOS_LIBS[@]}" -output "$COMBINED_LIB"
    
    # Copy the combined library
    cp "$COMBINED_LIB" "$FRAMEWORK_DIR/$FRAMEWORK_NAME"
    
    # Generate Swift bindings using the first macOS library (they should be identical)
    SWIFT_OUT_DIR="$BUILD_DIR/$TARGET/swift"
    mkdir -p "$SWIFT_OUT_DIR"
    
    cd "$PROJECT_DIR"
    cargo run --manifest-path uniffi-bindgen/Cargo.toml -- generate \
        --library "${MACOS_LIBS[0]}" \
        --language swift \
        --out-dir "$SWIFT_OUT_DIR"
    
    # Copy Swift files to framework if they exist
    if [ -d "$SWIFT_OUT_DIR" ]; then
        find "$SWIFT_OUT_DIR" -name "*.swift" -exec cp {} "$BINDINGS_DIR/Sources/MlsRs/" \;
        find "$SWIFT_OUT_DIR" -name "*.h" -exec cp {} "$FRAMEWORK_DIR/Headers/" \;
        
        # Create module map
        if [ -f "$SWIFT_OUT_DIR/mls_rs_uniffiFFI.h" ]; then
            cat > "$FRAMEWORK_DIR/Modules/module.modulemap" << EOF
framework module $FRAMEWORK_NAME {
    header "mls_rs_uniffiFFI.h"
    export *
}
EOF
        fi
    fi
    
    # Create Info.plist for macOS
    cat > "$FRAMEWORK_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.amazon.mls-rs.$FRAMEWORK_NAME</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$FRAMEWORK_NAME</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>0.7.0</string>
    <key>CFBundleVersion</key>
    <string>0.7.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF
    
    echo "Completed macOS framework"
fi

# Create XCFramework
echo "Creating XCFramework..."

XCFRAMEWORK_ARGS=()
for TARGET in "${TARGETS[@]}"; do
    FRAMEWORK_PATH="$BUILD_DIR/$TARGET/$FRAMEWORK_NAME.framework"
    if [ -d "$FRAMEWORK_PATH" ]; then
        XCFRAMEWORK_ARGS+=("-framework" "$FRAMEWORK_PATH")
    fi
done

# Add iOS Simulator framework if it was created
SIMULATOR_FRAMEWORK_PATH="$BUILD_DIR/ios-simulator/$FRAMEWORK_NAME.framework"
if [ -d "$SIMULATOR_FRAMEWORK_PATH" ]; then
    XCFRAMEWORK_ARGS+=("-framework" "$SIMULATOR_FRAMEWORK_PATH")
fi

# Add macOS framework if it was created
MACOS_FRAMEWORK_PATH="$BUILD_DIR/macos/$FRAMEWORK_NAME.framework"
if [ -d "$MACOS_FRAMEWORK_PATH" ]; then
    XCFRAMEWORK_ARGS+=("-framework" "$MACOS_FRAMEWORK_PATH")
fi

if [ ${#XCFRAMEWORK_ARGS[@]} -gt 0 ]; then
    xcodebuild -create-xcframework \
        "${XCFRAMEWORK_ARGS[@]}" \
        -output "$XCFRAMEWORK_PATH"
    
    echo "XCFramework created successfully at: $XCFRAMEWORK_PATH"
else
    echo "Error: No frameworks were built successfully"
    exit 1
fi

# Verify the XCFramework
if [ -d "$XCFRAMEWORK_PATH" ]; then
    echo "XCFramework contents:"
    find "$XCFRAMEWORK_PATH" -type f
    echo "Build completed successfully!"
else
    echo "Error: XCFramework was not created"
    exit 1
fi
