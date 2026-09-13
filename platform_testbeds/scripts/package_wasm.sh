#!/usr/bin/env bash
# Package mls-rs (RustCrypto backend) as standalone WebAssembly bindings.
#
# Produces platform_testbeds/dist/wasm/ containing wasm-bindgen output
# for both API modes and both common JS module styles:
#   sync/web/, sync/bundler/     default build — methods return values
#   async/web/, async/bundler/   RUSTFLAGS="--cfg mls_build_async" —
#                                MLS methods return Promises and
#                                IndexedDB writes are awaited per call
#
# `web` output loads in browsers or Node >= 18 directly; `bundler`
# output is for webpack/vite/rollup plugin flows.
#
# The source crate is platform_testbeds/wasm/mls-rs-wasm — copy it into
# your own workspace if you need to customise the exported API.
set -euo pipefail

TESTBED="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$TESTBED/dist/wasm"

cd "$TESTBED/wasm/mls-rs-wasm"

rm -rf "$DIST"

# Sync artifact (default build).
cargo build --release --target wasm32-unknown-unknown
for target in web bundler; do
    wasm-bindgen \
        --target "$target" \
        --out-dir "$DIST/sync/$target" \
        --out-name mls_rs_wasm \
        target/wasm32-unknown-unknown/release/mls_rs_wasm.wasm
done

# Async artifact (mls_build_async) — separate target dir so the sync
# artifacts stay intact.
RUSTFLAGS="--cfg mls_build_async" \
    cargo build --release --target wasm32-unknown-unknown \
    --target-dir target-async
for target in web bundler; do
    wasm-bindgen \
        --target "$target" \
        --out-dir "$DIST/async/$target" \
        --out-name mls_rs_wasm \
        target-async/wasm32-unknown-unknown/release/mls_rs_wasm.wasm
done

echo
echo "WASM packages written to $DIST"
find "$DIST" -type f | sed "s|$DIST/|  |"
