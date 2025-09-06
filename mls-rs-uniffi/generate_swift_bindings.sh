#!/bin/bash
# Script to generate Swift bindings for mls-rs-uniffi using UniFFI
# Usage: ./generate_swift_bindings.sh


set -e

echo "🛠️ Building mls-rs-uniffi debug dylib for macOS..."
cargo build --target aarch64-apple-darwin -p mls-rs-uniffi

LIB_PATH="target/aarch64-apple-darwin/debug/libmls_rs_uniffi.dylib"
if [ ! -f "$LIB_PATH" ]; then
  echo "Error: $LIB_PATH not found."
  exit 1
fi

echo "🔄 Generating Swift bindings..."
cargo run -p uniffi-bindgen -- generate --library "$LIB_PATH" --language swift --out-dir mls-rs-uniffi/swift/bindings

echo "✅ Swift bindings generated in mls-rs-uniffi/swift/bindings"
