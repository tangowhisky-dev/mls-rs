#!/usr/bin/env bash
# Android on-device end-to-end: builds .so files, stages bindings + PKI
# assets, boots an emulator if needed, and runs instrumented tests.
#
# Env: SKIP_BUILD=1 to reuse existing .so files; AVD=<name> to pick an AVD.
set -euo pipefail

TESTBED="$(cd "$(dirname "$0")/.." && pwd)"
APP="$TESTBED/android/app"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$ANDROID_HOME/platform-tools/adb"
EMU="$ANDROID_HOME/emulator/emulator"

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
    "$TESTBED/scripts/build_android.sh"
    "$TESTBED/scripts/gen_bindings.sh" kotlin
fi

# Stage generated Kotlin bindings into the app sources.
mkdir -p "$APP/src/main/java/uniffi/mls_rs_uniffi"
cp "$TESTBED/gen/kotlin/uniffi/mls_rs_uniffi/"*.kt \
   "$APP/src/main/java/uniffi/mls_rs_uniffi/"

# Stage X.509 test material into androidTest assets.
mkdir -p "$APP/src/androidTest/assets"
cp -R "$TESTBED/test_pki" "$APP/src/androidTest/assets/"

# Ensure a device/emulator is up.
if ! "$ADB" devices | grep -qw "device$"; then
    avd="${AVD:-$("$EMU" -list-avds | head -1)}"
    if [[ -z "$avd" ]]; then
        echo "No device connected and no AVDs configured." >&2
        exit 1
    fi
    echo "Booting emulator: $avd"
    "$EMU" -avd "$avd" -no-window -no-audio -gpu swiftshader_indirect \
        >/tmp/mlsrs-emulator.log 2>&1 &
    "$ADB" wait-for-device
    # Wait for full boot (sys.boot_completed can lag device attach).
    for _ in $(seq 1 60); do
        [[ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]] && break
        sleep 5
    done
fi
"$ADB" devices

cd "$TESTBED/android"
gradle connectedDebugAndroidTest --console=plain
