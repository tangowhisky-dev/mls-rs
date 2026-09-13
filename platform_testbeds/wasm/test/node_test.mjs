// Node.js end-to-end test for the mls-rs WASM bindings.
//
//   node test/node_test.mjs
//
// Uses Node's global WebAssembly + crypto (getrandom js backend).

import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");

// Initialize the wasm module from the compiled artifact.
// MLS_PKG=async selects the `mls_build_async` build (pkg-async/).
const pkgDir = process.env.MLS_PKG === "async" ? "pkg-async" : "pkg";
const wasm = await import(`../${pkgDir}/mls_rs_wasm.js`);
const wasmBytes = await readFile(
  path.join(root, `wasm/${pkgDir}/mls_rs_wasm_bg.wasm`),
);
await wasm.default({ module_or_path: wasmBytes });
console.log(`wasm package: ${pkgDir}`);

const loadCert = (rel) => readFile(path.join(root, rel));

const { runAll, runInterop } = await import("./run_scenarios.mjs");
// MLS_INTEROP_ONLY=1 skips the local e2e suite (used when the interop
// script loops cipher suites).
if (!process.env.MLS_INTEROP_ONLY) {
  await runAll(wasm, loadCert);
}

// Cross-language wire interop when MLS_FIXTURE_DIR/MLS_HARNESS_BIN
// are set (scripts/test_interop.sh): emit a key package, let the
// Rust harness build a welcome around it, join and decrypt.
if (process.env.MLS_FIXTURE_DIR && process.env.MLS_HARNESS_BIN) {
  const { execFileSync } = await import("node:child_process");
  const dir = process.env.MLS_FIXTURE_DIR;
  const suiteName = process.env.MLS_SUITE ?? "Curve25519Aes128";
  await runInterop(wasm, {
    readFixture: async (name) => {
      try {
        return await readFile(path.join(dir, name));
      } catch {
        return null;
      }
    },
    writeFixture: (name, bytes) => writeFile(path.join(dir, name), bytes),
    runHarness: (args = ["--make-welcome"]) =>
      execFileSync(process.env.MLS_HARNESS_BIN, [args[0], dir, suiteName]),
    suiteName,
    id: "bob-wasm",
  });
  console.log(
    "PASS wasm interop + differential (Rust consumed KP+msg, WASM matched golden outputs)",
  );
}
