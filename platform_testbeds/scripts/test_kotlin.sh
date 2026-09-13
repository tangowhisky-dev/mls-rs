#!/usr/bin/env bash
# Kotlin/JVM end-to-end test of the generated UniFFI bindings.
#
# Compiles the generated Kotlin bindings, downloads JNA from Maven
# Central, and runs android/e2e.kts against the host build of
# libmls_rs_uniffi (RustCrypto backend). This validates the same
# binding surface an Android app uses; on-device coverage additionally
# requires an emulator (see android/README).
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$(cd .. && pwd)"
GEN="gen/kotlin"
DEPS="deps"
mkdir -p "$DEPS"

JNA_VERSION="5.14.0"
JNA_JAR="$DEPS/jna-$JNA_VERSION.jar"
if [[ ! -f "$JNA_JAR" ]]; then
    echo "Downloading JNA $JNA_VERSION"
    curl -fsSL -o "$JNA_JAR" \
        "https://repo1.maven.org/maven2/net/java/dev/jna/jna/$JNA_VERSION/jna-$JNA_VERSION.jar"
fi

if [[ ! -f "$GEN/uniffi/mls_rs_uniffi/mls_rs_uniffi.kt" ]]; then
    echo "Kotlin bindings missing; run scripts/gen_bindings.sh first" >&2
    exit 1
fi

BINDINGS_JAR="$DEPS/mls_rs_uniffi_bindings.jar"
if [[ ! -f "$BINDINGS_JAR" || "$GEN/uniffi/mls_rs_uniffi/mls_rs_uniffi.kt" -nt "$BINDINGS_JAR" ]]; then
    echo "Compiling Kotlin bindings"
    kotlinc "$GEN/uniffi/mls_rs_uniffi/mls_rs_uniffi.kt" \
        -classpath "$JNA_JAR" -d "$BINDINGS_JAR"
fi

# Make sure the host dylib exists.
if [[ ! -f "$ROOT/target/debug/libmls_rs_uniffi.dylib" ]]; then
    (cd "$ROOT" && cargo build -p mls-rs-uniffi --lib)
fi

export MLS_TESTBED_ROOT="$PWD"
export JNA_LIBRARY_PATH="$ROOT/target/debug"

kotlinc -classpath "$JNA_JAR:$BINDINGS_JAR" \
    -Djna.library.path="$JNA_LIBRARY_PATH" \
    -script android/e2e.kts
