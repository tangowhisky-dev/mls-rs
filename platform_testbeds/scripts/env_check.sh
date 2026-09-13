#!/usr/bin/env bash
# Verify the toolchain pieces each platform testbed needs.
# Prints [ok]/[missing] per item; exit non-zero if any required item is absent.
set -uo pipefail

required_missing=0

check() {
    local label="$1" required="$2" cmd="$3"
    if eval "$cmd" >/dev/null 2>&1; then
        echo "[ok]      $label"
    elif [[ "$required" == "req" ]]; then
        echo "[MISSING] $label"
        required_missing=1
    else
        echo "[skip]    $label (optional)"
    fi
}

target_installed() { rustup target list --installed 2>/dev/null | grep -qx "$1"; }

check "rust toolchain"            req "cargo --version"
check "rustup"                    req "rustup --version"
check "openssl CLI (test PKI)"    req "openssl version"
check "python3 (key exporter)"    req "python3 --version"
check "wasm32 target"             req "target_installed wasm32-unknown-unknown"
check "wasm-bindgen CLI"          req "wasm-bindgen --version"
check "node"                      req "node --version"
check "kotlinc"                   opt "kotlinc -version"
check "cargo-ndk"                 opt "cargo ndk --version"
check "Android NDK"               opt "ls -d \$HOME/Library/Android/sdk/ndk/* \$ANDROID_HOME/ndk/*"
check "adb"                       opt "\$HOME/Library/Android/sdk/platform-tools/adb --version"
check "Android emulator"          opt "\$HOME/Library/Android/sdk/emulator/emulator -list-avds"
check "gradle"                    opt "gradle --version"
check "xcodebuild"                opt "xcodebuild -version"
check "ios-sim target"            opt "target_installed aarch64-apple-ios-sim"
check "ios device target"         opt "target_installed aarch64-apple-ios"
check "x86 Android target"        opt "target_installed x86_64-linux-android"
check "arm64 Android target"      opt "target_installed aarch64-linux-android"
check "Google Chrome (browser e2e)" opt "ls '/Applications/Google Chrome.app'"

exit $required_missing
