#!/usr/bin/env bash
# Build libmls_rs_uniffi as static libraries for iOS device,
# iOS simulator and macOS, and package them as an XCFramework.
set -euo pipefail

cd "$(dirname "$0")/../.."
OUT="platform_testbeds/gen"
mkdir -p "$OUT"

for target in aarch64-apple-ios aarch64-apple-ios-sim aarch64-apple-darwin; do
    echo "Building mls-rs-uniffi for $target"
    cargo build -p mls-rs-uniffi --lib --release --target "$target"
done

# Stage a clean FFI headers dir: Xcode requires the module map to be
# named `module.modulemap` inside an XCFramework's Headers dir.
HEADERS="$OUT/ffi-headers"
rm -rf "$HEADERS"
mkdir -p "$HEADERS"
cp "$OUT/swift/mls_rs_uniffiFFI.h" "$HEADERS/"
cp "$OUT/swift/mls_rs_uniffiFFI.modulemap" "$HEADERS/module.modulemap"

rm -rf "$OUT/MlsRsUniffiFFI.xcframework"
xcodebuild -create-xcframework \
    -library "target/aarch64-apple-ios/release/libmls_rs_uniffi.a" \
    -headers "$HEADERS" \
    -library "target/aarch64-apple-ios-sim/release/libmls_rs_uniffi.a" \
    -headers "$HEADERS" \
    -library "target/aarch64-apple-darwin/release/libmls_rs_uniffi.a" \
    -headers "$HEADERS" \
    -output "$OUT/MlsRsUniffiFFI.xcframework"

echo "XCFramework written to $OUT/MlsRsUniffiFFI.xcframework"
