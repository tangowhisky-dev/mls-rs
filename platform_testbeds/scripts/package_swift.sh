#!/usr/bin/env bash
# Package mls-rs (RustCrypto backend) as a standalone Swift package.
#
# Produces platform_testbeds/dist/swift/MlsRsUniffi/ — a ready-to-use
# SwiftPM package:
#   Package.swift
#   MlsRsUniffiFFI.xcframework/         Rust static libs + FFI module map
#   Sources/mls_rs_uniffi/...          generated UniFFI Swift bindings
#
# Options:
#   --macos-only   build only the macOS slice (no iOS device/sim slices)
set -euo pipefail

TESTBED="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$TESTBED/.." && pwd)"
GEN="$TESTBED/gen"
DIST="$TESTBED/dist/swift"
PKG_DIR="$DIST/MlsRsUniffi"

MACOS_ONLY=0
for arg in "$@"; do
    case "$arg" in
        --macos-only) MACOS_ONLY=1 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

cd "$ROOT"

# --- bindings ---
"$TESTBED/scripts/gen_bindings.sh" swift

# --- static libraries + XCFramework ---
HEADERS="$GEN/ffi-headers"
mkdir -p "$HEADERS"
cp "$GEN/swift/mls_rs_uniffiFFI.h" "$HEADERS/"
cp "$GEN/swift/mls_rs_uniffiFFI.modulemap" "$HEADERS/module.modulemap"

XCF_ARGS=()
if [[ "$MACOS_ONLY" == "1" ]]; then
    targets=(aarch64-apple-darwin)
else
    targets=(aarch64-apple-ios aarch64-apple-ios-sim aarch64-apple-darwin)
fi

for target in "${targets[@]}"; do
    echo "Building mls-rs-uniffi for $target"
    cargo build -p mls-rs-uniffi --lib --release --target "$target"
    XCF_ARGS+=(-library "target/$target/release/libmls_rs_uniffi.a" -headers "$HEADERS")
done

rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/Sources/mls_rs_uniffi"
xcodebuild -create-xcframework "${XCF_ARGS[@]}" \
    -output "$PKG_DIR/MlsRsUniffiFFI.xcframework"
cp "$GEN/swift/mls_rs_uniffi.swift" "$PKG_DIR/Sources/mls_rs_uniffi/"

cat > "$PKG_DIR/Package.swift" <<'EOF'
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MlsRsUniffi",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "mls_rs_uniffi", targets: ["mls_rs_uniffi"]),
    ],
    targets: [
        // Rust static libraries (mls-rs-uniffi, RustCrypto backend).
        .binaryTarget(
            name: "mls_rs_uniffiFFI",
            path: "MlsRsUniffiFFI.xcframework"
        ),
        // Generated UniFFI Swift bindings.
        .target(
            name: "mls_rs_uniffi",
            dependencies: ["mls_rs_uniffiFFI"]
        ),
    ]
)
EOF

echo
echo "Swift package written to $PKG_DIR"
find "$PKG_DIR" -maxdepth 2 -not -path "*/MlsRsUniffiFFI.xcframework/*" | sed "s|$PKG_DIR|  MlsRsUniffi|"
echo "  MlsRsUniffi/MlsRsUniffiFFI.xcframework slices: $(ls "$PKG_DIR/MlsRsUniffiFFI.xcframework" | grep -v Info.plist | tr '\n' ' ')"
