#!/usr/bin/env bash
# Package mls-rs (RustCrypto backend) as standalone Kotlin/Java bindings.
#
# Produces platform_testbeds/dist/kotlin/ containing:
#   bindings/uniffi/mls_rs_uniffi/mls_rs_uniffi.kt   generated UniFFI bindings
#   jniLibs/<abi>/libmls_rs_uniffi.so                Android native libs (4 ABIs)
#   host/<triple>/libmls_rs_uniffi.<ext>             host lib for JVM/desktop
#
# Options:
#   --skip-android   only emit host library + bindings (no NDK required)
#   --skip-host      only emit Android jniLibs + bindings
#   --debug          build the host library in debug profile (default: release)
set -euo pipefail

TESTBED="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$TESTBED/.." && pwd)"
DIST="$TESTBED/dist/kotlin"

SKIP_ANDROID=0
SKIP_HOST=0
PROFILE="release"
for arg in "$@"; do
    case "$arg" in
        --skip-android) SKIP_ANDROID=1 ;;
        --skip-host)    SKIP_HOST=1 ;;
        --debug)        PROFILE="debug" ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

cd "$ROOT"

# --- bindings (always regenerated so they match the built library) ---
"$TESTBED/scripts/gen_bindings.sh" kotlin

rm -rf "$DIST"
mkdir -p "$DIST/bindings/uniffi/mls_rs_uniffi"
cp "$TESTBED/gen/kotlin/uniffi/mls_rs_uniffi/"*.kt \
   "$DIST/bindings/uniffi/mls_rs_uniffi/"

# --- host library (JVM/desktop, loaded via JNA) ---
if [[ "$SKIP_HOST" != "1" ]]; then
    profile_flag="--release"
    [[ "$PROFILE" == "debug" ]] && profile_flag=""
    cargo build -p mls-rs-uniffi --lib $profile_flag

    triple="$(rustc -vV | awk '/^host:/ {print $2}')"
    ext="so"; [[ "$triple" == *-apple-* ]] && ext="dylib"
    [[ "$triple" == *-windows-* ]] && ext="dll"
    mkdir -p "$DIST/host/$triple"
    cp "target/$PROFILE/libmls_rs_uniffi.$ext" "$DIST/host/$triple/"
    echo "host lib   -> $DIST/host/$triple/libmls_rs_uniffi.$ext"
fi

# --- Android jniLibs ---
if [[ "$SKIP_ANDROID" != "1" ]]; then
    "$TESTBED/scripts/build_android.sh"
    mkdir -p "$DIST/jniLibs"
    cp -R "$TESTBED/android/app/src/main/jniLibs/"* "$DIST/jniLibs/"
    echo "jniLibs    -> $DIST/jniLibs ($(ls "$DIST/jniLibs" | tr '\n' ' '))"
fi

echo
echo "Kotlin package written to $DIST"
find "$DIST" -type f | sed "s|$DIST/|  |"
