// Node.js persistence test for the mls-rs WASM bindings.
//
//   npm install   (once, in wasm/test)
//   node test/node_persistence.mjs            # sync artifact
//   MLS_PKG=async node test/node_persistence.mjs
//
// `fake-indexeddb/auto` installs a spec-complete IndexedDB on
// globalThis, which is what the `idb` crate's `Factory::new()` reads.

import "fake-indexeddb/auto";
import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const pkgDir = process.env.MLS_PKG === "async" ? "pkg-async" : "pkg";

const wasm = await import(`../${pkgDir}/mls_rs_wasm.js`);
const wasmBytes = await readFile(
  path.join(root, `wasm/${pkgDir}/mls_rs_wasm_bg.wasm`),
);
await wasm.default({ module_or_path: wasmBytes });
console.log(`wasm package: ${pkgDir}`);

const { runPersistence } = await import("./run_scenarios.mjs");
await runPersistence(wasm);
