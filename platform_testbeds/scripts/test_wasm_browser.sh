#!/usr/bin/env bash
# Run the WASM e2e + IndexedDB persistence scenarios in headless Chrome.
#
# Serves the platform_testbeds directory over a local HTTP server and
# drives real headless Chrome over the DevTools protocol
# (wasm/test/cdp_run.mjs) — once per artifact: the sync build in
# wasm/pkg and the `mls_build_async` build in wasm/pkg-async.
set -euo pipefail

cd "$(dirname "$0")/.."
PORT="${PORT:-8765}"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"

missing=0
for pkg in pkg pkg-async; do
    if [[ ! -f "wasm/$pkg/mls_rs_wasm_bg.wasm" ]]; then
        echo "wasm/$pkg missing; run scripts/build_wasm.sh first" >&2
        missing=1
    fi
done
[[ $missing -eq 0 ]] || exit 1

python3 -m http.server "$PORT" --bind 127.0.0.1 >/dev/null 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null || true' EXIT
sleep 1

status=0
for pkg in sync async; do
    echo "=== artifact: $pkg ==="
    if node wasm/test/cdp_run.mjs \
        "http://127.0.0.1:$PORT/wasm/web/index.html?pkg=$pkg" \
        "$CHROME" 120000; then
        echo "WASM browser e2e ($pkg): PASS"
    else
        echo "WASM browser e2e ($pkg): FAIL" >&2
        status=1
    fi
done
exit $status
