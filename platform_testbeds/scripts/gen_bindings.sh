#!/usr/bin/env bash
# Generate UniFFI bindings (Kotlin + Swift) for mls-rs-uniffi.
#
# Uses the workspace's `uniffi-bindgen` crate so the generator version
# always matches the `uniffi` dependency.
set -euo pipefail

cd "$(dirname "$0")/../.."

OUT="platform_testbeds/gen"
LANG="${1:-all}"

cargo build -p mls-rs-uniffi --lib
LIB="$PWD/target/debug/libmls_rs_uniffi.dylib"

if [[ "$LANG" == "all" || "$LANG" == "kotlin" ]]; then
    mkdir -p "$OUT/kotlin"
    cargo run -p uniffi-bindgen --quiet -- \
        generate --library "$LIB" --language kotlin --out-dir "$OUT/kotlin"
    echo "Kotlin bindings -> $OUT/kotlin"
fi

if [[ "$LANG" == "all" || "$LANG" == "swift" ]]; then
    mkdir -p "$OUT/swift"
    cargo run -p uniffi-bindgen --quiet -- \
        generate --library "$LIB" --language swift --out-dir "$OUT/swift"
    echo "Swift bindings  -> $OUT/swift"
fi
