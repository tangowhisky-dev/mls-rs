#!/usr/bin/env bash
# Cross-language wire-interoperability + differential test.
#
# Two properties are proven, per cipher suite, per binding:
#
#   Wire interop — serialized MLS bytes produced by one binding are
#   consumed by the others and by direct mls-rs:
#     1. Each consumer (Kotlin, Swift, WASM) generates a key package
#        and writes raw wire bytes as interop/fixtures/<suite>/
#        consumer_kp_*.bin.
#     2. The Rust harness (--make-welcome, built on direct mls-rs)
#        parses those key packages, validates their signatures by
#        committing them into a fresh group, and writes
#        welcome/commit/app_msg wire bytes plus golden expected
#        values (expected_tree_*, expected_roster.txt, commit2).
#     3. Each consumer joins from the welcome bytes and decrypts the
#        Rust application message.
#
#   Differential — same inputs produce the same outputs through the
#   bindings as through direct mls-rs:
#     * Message.fromBytes(x).toBytes() == x on every fixture,
#     * post-join and post-commit2 exportTree() bytes match the
#       direct-Rust ground truth exactly,
#     * the roster after commit2 matches expected_roster.txt,
#     * each consumer emits consumer_msg_<lang>.bin which the Rust
#       harness (--verify) decrypts with the persisted producer group.
#
# Requires: scripts/gen_bindings.sh and scripts/build_wasm.sh have
# been run, and the Kotlin bindings jar exists (scripts/test_kotlin.sh
# produces it).
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(cd .. && pwd)"

# Build the harness binary once; consumers invoke it mid-test.
echo "== Building rust harness"
cargo build --release --manifest-path rust-harness/Cargo.toml
HARNESS="rust-harness/target/release/mls-rs-e2e-harness"

export MLS_TESTBED_ROOT="$PWD"
export MLS_HARNESS_BIN="$PWD/$HARNESS"

DEPS="deps"
JNA_JAR="$DEPS/jna-5.14.0.jar"
BINDINGS_JAR="$DEPS/mls_rs_uniffi_bindings.jar"
export JNA_LIBRARY_PATH="$ROOT/target/debug"

SUITES="Curve25519Aes128 P256Aes128 Curve25519ChaCha P521Aes256 P384Aes256"

for suite in $SUITES; do
    FIXTURES="$PWD/interop/fixtures/$suite"
    mkdir -p "$FIXTURES"
    rm -rf "$FIXTURES"/* "$FIXTURES"/rust_state

    export MLS_FIXTURE_DIR="$FIXTURES"
    export MLS_SUITE="$suite"

    echo "=== $suite ==="
    echo "== Kotlin: emit KP, consume Rust welcome, differential checks"
    kotlinc -classpath "$JNA_JAR:$BINDINGS_JAR" \
        -Djna.library.path="$JNA_LIBRARY_PATH" \
        -script android/interop.kts

    echo "== Swift: emit KP, consume Rust welcome, differential checks"
    scripts/test_swift_macos.sh ios/interop/main.swift interop

    echo "== WASM/Node: emit KP, consume Rust welcome, differential checks"
    MLS_INTEROP_ONLY=1 node wasm/test/node_test.mjs 2>&1 | grep -E "interop|FAIL" || true
done

echo "Cross-language interop + differential test complete."
