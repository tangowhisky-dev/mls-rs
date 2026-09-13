// Browser runner for the mls-rs WASM e2e scenarios. Serve the
// platform_testbeds directory over HTTP and open wasm/web/index.html,
// or use scripts/test_wasm_browser.sh which drives a headless browser.
//
// `?pkg=async` tests the `mls_build_async` artifact (pkg-async/);
// the default is the synchronous build (pkg/).

const log = (msg) => {
  const el = document.getElementById("log");
  const line = document.createElement("div");
  line.textContent = msg;
  line.className = msg.startsWith("FAIL") ? "fail" : "pass";
  el.appendChild(line);
};

const loadCert = async (rel) => {
  const resp = await fetch(`../../${rel}`);
  if (!resp.ok) throw new Error(`fetch ${rel}: ${resp.status}`);
  return resp.arrayBuffer();
};

const pkgDir = new URLSearchParams(location.search).get("pkg") === "async"
  ? "pkg-async"
  : "pkg";

try {
  const wasm = await import(`../${pkgDir}/mls_rs_wasm.js`);
  await wasm.default();
  const { runAll, runPersistence } = await import("../test/run_scenarios.mjs");
  await runAll(wasm, loadCert, log);
  // IndexedDB persistence scenarios only make sense in a real browser.
  await runPersistence(wasm, log);
  document.title = `mls-rs WASM (${pkgDir}): PASS`;
} catch (e) {
  log(`FATAL ${e}`);
  document.title = `mls-rs WASM (${pkgDir}): FAIL`;
  throw e;
}
