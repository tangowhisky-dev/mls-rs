#!/usr/bin/env bash
# Build libmls_rs_uniffi shared objects for Android ABIs into a
# jniLibs/ layout consumable by a Gradle Android project.
set -euo pipefail

cd "$(dirname "$0")/../.."
OUT="platform_testbeds/android/app/src/main/jniLibs"

: "${ANDROID_HOME:=$HOME/Library/Android/sdk}"
if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
    ndk_dir="$(ls -d "$ANDROID_HOME"/ndk/* 2>/dev/null | sort -V | tail -1 || true)"
    if [[ -n "$ndk_dir" ]]; then
        export ANDROID_NDK_HOME="$ndk_dir"
    else
        echo "ANDROID_NDK_HOME not set and no NDK found under $ANDROID_HOME/ndk" >&2
        exit 1
    fi
fi
export ANDROID_HOME
echo "Using NDK: $ANDROID_NDK_HOME"

# cargo-ndk target triples -> jniLibs ABI dirs
cargo ndk \
    --target aarch64-linux-android \
    --target armv7-linux-androideabi \
    --target x86_64 \
    --target i686-linux-android \
    --platform 24 \
    build -p mls-rs-uniffi --lib --release

mkdir -p "$OUT"/{arm64-v8a,armeabi-v7a,x86_64,x86}
cp target/aarch64-linux-android/release/libmls_rs_uniffi.so   "$OUT/arm64-v8a/"
cp target/armv7-linux-androideabi/release/libmls_rs_uniffi.so "$OUT/armeabi-v7a/"
cp target/x86_64-linux-android/release/libmls_rs_uniffi.so    "$OUT/x86_64/"
cp target/i686-linux-android/release/libmls_rs_uniffi.so      "$OUT/x86/"

echo "Android .so files written to $OUT"
find "$OUT" -name "*.so" -exec ls -lh {} +
