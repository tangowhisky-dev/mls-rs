#!/usr/bin/env bash
# Build the mls-rs WASM bindings and emit the wasm-bindgen packages.
#
# Two artifacts are produced:
#   ../pkg/       synchronous API (default mls-rs build)
#   ../pkg-async/ async API (RUSTFLAGS="--cfg mls_build_async") —
#               MLS methods return Promises and IndexedDB persistence
#               writes are awaited inside each call.
#
# Both share the same wire formats; pick the artifact matching how you
# want to drive the API.
set -euo pipefail

cd "$(dirname "$0")/../wasm/mls-rs-wasm"

cargo build --release --target wasm32-unknown-unknown

wasm-bindgen \
    --target web \
    --out-dir ../pkg \
    --out-name mls_rs_wasm \
    target/wasm32-unknown-unknown/release/mls_rs_wasm.wasm

RUSTFLAGS="--cfg mls_build_async" \
    cargo build --release --target wasm32-unknown-unknown \
    --target-dir target-async

wasm-bindgen \
    --target web \
    --out-dir ../pkg-async \
    --out-name mls_rs_wasm \
    target-async/wasm32-unknown-unknown/release/mls_rs_wasm.wasm

echo "WASM packages written to platform_testbeds/wasm/pkg (sync) and pkg-async (async)"
