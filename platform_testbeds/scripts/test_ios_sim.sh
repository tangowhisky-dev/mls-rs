#!/usr/bin/env bash
# Run the mls-rs e2e suite on an iOS Simulator.
#
# Builds the XCFramework (scripts/build_ios.sh), assembles the
# SwiftPM package in ios/MlsRsTestbed (generated bindings + test PKI
# resources) and runs `xcodebuild test`.
set -euo pipefail

cd "$(dirname "$0")/.."
PKG="ios/MlsRsTestbed"

if [[ ! -d gen/MlsRsUniffiFFI.xcframework ]]; then
    echo "XCFramework missing; run scripts/build_ios.sh first" >&2
    exit 1
fi
if [[ ! -f gen/swift/mls_rs_uniffi.swift ]]; then
    echo "Swift bindings missing; run scripts/gen_bindings.sh first" >&2
    exit 1
fi
if [[ ! -d test_pki/p256_alice ]]; then
    echo "test PKI missing; run scripts/gen_test_pki.sh first" >&2
    exit 1
fi

mkdir -p "$PKG/Sources/mls_rs_uniffi"
cp gen/swift/mls_rs_uniffi.swift "$PKG/Sources/mls_rs_uniffi/mls_rs_uniffi.swift"

mkdir -p "$PKG/Tests/MlsRsE2ETests/Resources"
rm -rf "$PKG/Tests/MlsRsE2ETests/Resources/test_pki"
cp -R test_pki "$PKG/Tests/MlsRsE2ETests/Resources/test_pki"

# Pick an available iPhone simulator on the *newest* iOS runtime —
# `xcodebuild -destination name=…` implies `OS:latest`, so a device that
# only exists on an older runtime never matches.
if [[ -z "${IOS_DESTINATION:-}" ]]; then
    sim="$(xcrun simctl list devices available -j \
        | python3 -c '
import json, sys, re
d = json.load(sys.stdin)["devices"]
def ver(rt):
    m = re.search(r"iOS-(\d+)-(\d+)", rt)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)
for rt in sorted(d, key=ver, reverse=True):
    phones = [dev["name"] for dev in d[rt]
              if dev.get("isAvailable") and "iPhone" in dev["name"]]
    if phones:
        print(phones[-1]); break
')"
    if [[ -z "$sim" ]]; then
        echo "No available iPhone simulator found." >&2
        exit 1
    fi
    IOS_DESTINATION="platform=iOS Simulator,name=$sim"
fi
DESTINATION="$IOS_DESTINATION"
echo "xcodebuild test on: $DESTINATION"
cd "$PKG"
xcodebuild test \
    -scheme MlsRsTestbed \
    -destination "$DESTINATION" \
    -skipPackagePluginValidation \
    2>&1 | tail -40
