#!/usr/bin/env bash
# Run every available platform testbed in sequence.
# Per-platform steps that lack prerequisites are skipped with a notice.
set -uo pipefail

TESTBED="$(cd "$(dirname "$0")/.." && pwd)"
declare -a results=()

run() {
    local label="$1"; shift
    echo "================================================================"
    echo "=== $label"
    echo "================================================================"
    if "$@"; then
        results+=("PASS $label")
    else
        results+=("FAIL $label")
    fi
}

have() { command -v "$1" >/dev/null 2>&1; }

# --- Rust native harness (always available) ---
run "Rust harness (cargo testbed)" \
    cargo run --release --manifest-path "$TESTBED/rust-harness/Cargo.toml"

# --- WASM ---
if have wasm-bindgen && have node; then
    run "WASM build" "$TESTBED/scripts/build_wasm.sh"
    run "WASM Node e2e (sync)" node "$TESTBED/wasm/test/node_test.mjs"
    run "WASM Node e2e (async)" env MLS_PKG=async node "$TESTBED/wasm/test/node_test.mjs"
    if [[ -f "$TESTBED/wasm/test/node_modules/fake-indexeddb/package.json" ]]; then
        run "WASM Node persistence (sync)" \
            node "$TESTBED/wasm/test/node_persistence.mjs"
        run "WASM Node persistence (async)" \
            env MLS_PKG=async node "$TESTBED/wasm/test/node_persistence.mjs"
    else
        results+=("SKIP WASM persistence (cd wasm/test && npm install)")
    fi
    if [[ -d "/Applications/Google Chrome.app" ]]; then
        run "WASM browser e2e" "$TESTBED/scripts/test_wasm_browser.sh"
    else
        results+=("SKIP WASM browser e2e (no Chrome)")
    fi
else
    results+=("SKIP WASM (need wasm-bindgen-cli + node)")
fi

# --- Kotlin/JVM ---
if have kotlinc; then
    run "Kotlin/JVM e2e" "$TESTBED/scripts/test_kotlin.sh"
else
    results+=("SKIP Kotlin/JVM (need kotlinc)")
fi

# --- Swift/macOS ---
if have swiftc; then
    run "Swift macOS e2e" "$TESTBED/scripts/test_swift_macos.sh"
else
    results+=("SKIP Swift macOS (need swiftc)")
fi

# --- Cross-language wire interop (needs Kotlin bindings jar +
#     wasm pkg from the steps above, plus swiftc) ---
if have kotlinc && have swiftc && have node && \
   [[ -f "$TESTBED/gen/kotlin/uniffi/mls_rs_uniffi/mls_rs_uniffi.kt" ]] && \
   [[ -f "$TESTBED/wasm/pkg/mls_rs_wasm.js" ]]; then
    run "Cross-language wire interop" "$TESTBED/scripts/test_interop.sh"
else
    results+=("SKIP interop (need kotlin bindings + wasm pkg + swiftc)")
fi

# --- Android on-device ---
if have cargo && cargo ndk --version >/dev/null 2>&1 && have gradle; then
    run "Android emulator e2e" "$TESTBED/scripts/test_android.sh"
else
    results+=("SKIP Android (need cargo-ndk + gradle + SDK)")
fi

# --- iOS simulator ---
if have xcodebuild; then
    run "iOS build" "$TESTBED/scripts/build_ios.sh"
    run "iOS simulator e2e" "$TESTBED/scripts/test_ios_sim.sh"
else
    results+=("SKIP iOS (need Xcode)")
fi

echo
echo "================== SUMMARY =================="
printf '%s\n' "${results[@]}"
! printf '%s\n' "${results[@]}" | grep -q "^FAIL"
