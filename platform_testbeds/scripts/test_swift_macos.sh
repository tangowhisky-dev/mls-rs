#!/usr/bin/env bash
# Compile and run the Swift e2e harness on macOS against the host
# build of libmls_rs_uniffi (RustCrypto backend).
#
# Two steps:
#   1. compile the generated UniFFI Swift bindings into a
#      `mls_rs_uniffi` module (dylib + swiftmodule)
#   2. compile ios/src/main.swift against that module and run it
#
# An alternate driver can be given: `test_swift_macos.sh <src> <bin>`
# (used by test_interop.sh with ios/interop/main.swift).
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(cd .. && pwd)"
OUT="gen/swift-build"
mkdir -p "$OUT"

SRC="${1:-ios/src/main.swift}"
BIN="${2:-e2e}"

if [[ ! -f gen/swift/mls_rs_uniffi.swift ]]; then
    echo "Swift bindings missing; run scripts/gen_bindings.sh first" >&2
    exit 1
fi

if [[ ! -f "$ROOT/target/debug/libmls_rs_uniffi.dylib" ]]; then
    (cd "$ROOT" && cargo build -p mls-rs-uniffi --lib)
fi

echo "Compiling mls_rs_uniffi Swift module"
swiftc -O \
    -emit-module -emit-library \
    -module-name mls_rs_uniffi \
    gen/swift/mls_rs_uniffi.swift \
    -Xcc -fmodule-map-file="$PWD/gen/swift/mls_rs_uniffiFFI.modulemap" \
    -emit-module-path "$OUT/mls_rs_uniffi.swiftmodule" \
    -o "$OUT/libmls_rs_uniffi_bindings.dylib" \
    -L "$ROOT/target/debug" -lmls_rs_uniffi

echo "Compiling $BIN driver ($SRC)"
swiftc -O \
    -o "$OUT/$BIN" \
    "$SRC" \
    -I "$OUT" \
    -Xcc -fmodule-map-file="$PWD/gen/swift/mls_rs_uniffiFFI.modulemap" \
    -L "$OUT" -L "$ROOT/target/debug" \
    -lmls_rs_uniffi_bindings -lmls_rs_uniffi \
    -Xlinker -rpath -Xlinker "$OUT" \
    -Xlinker -rpath -Xlinker "$ROOT/target/debug"

export MLS_TESTBED_ROOT="$PWD"
"$OUT/$BIN"
