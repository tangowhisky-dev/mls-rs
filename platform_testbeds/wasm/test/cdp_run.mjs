// Minimal Chrome DevTools Protocol driver for the WASM test page —
// waits in *real* time for the page title to become PASS/FAIL, then
// prints the log lines. `--virtual-time-budget` can't be used for
// IndexedDB scenarios: it fast-forwards timers without waiting for
// real async storage I/O.
//
// Usage: node cdp_run.mjs <url> <chrome-path> [timeout-ms]

import { spawn } from "node:child_process";

const [, , url, chrome, timeoutMs = "120000"] = process.argv;
const timeout = Number(timeoutMs);
const port = 9222 + Math.floor(Math.random() * 1000);

const proc = spawn(chrome, [
  "--headless=new",
  "--disable-gpu",
  "--no-sandbox",
  `--remote-debugging-port=${port}`,
  "about:blank",
]);

const kill = () => {
  try {
    proc.kill("SIGKILL");
  } catch {}
};
process.on("exit", kill);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Wait for the debugger endpoint.
let wsUrl = null;
for (let i = 0; i < 100; i++) {
  try {
    const res = await fetch(`http://127.0.0.1:${port}/json/version`);
    const { webSocketDebuggerUrl } = await res.json();
    wsUrl = webSocketDebuggerUrl;
    break;
  } catch {
    await sleep(200);
  }
}
if (!wsUrl) {
  console.error("FAIL could not reach Chrome DevTools endpoint");
  kill();
  process.exit(1);
}

const ws = new WebSocket(wsUrl);
await new Promise((resolve, reject) => {
  ws.onopen = resolve;
  ws.onerror = reject;
});

let nextId = 1;
const pending = new Map();
ws.onmessage = (event) => {
  const msg = JSON.parse(event.data);
  if (msg.id && pending.has(msg.id)) {
    pending.get(msg.id)(msg);
    pending.delete(msg.id);
  }
};
const send = (method, params = {}) =>
  new Promise((resolve) => {
    const id = nextId++;
    pending.set(id, resolve);
    ws.send(JSON.stringify({ id, method, params }));
  });

// Create a target, attach, navigate.
const { result: { targetId } } = await send("Target.createTarget", { url: "about:blank" });
const { result: { sessionId } } = await send("Target.attachToTarget", {
  targetId,
  flatten: true,
});
const sendSession = (method, params = {}) =>
  new Promise((resolve) => {
    const id = nextId++;
    pending.set(id, resolve);
    ws.send(JSON.stringify({ id, method, params, sessionId }));
  });

await sendSession("Page.enable");
await sendSession("Runtime.enable");
await sendSession("Page.navigate", { url });

const evalJs = async (expr) => {
  const res = await sendSession("Runtime.evaluate", {
    expression: expr,
    returnByValue: true,
  });
  return res.result?.result?.value;
};

const deadline = Date.now() + timeout;
let title = "";
while (Date.now() < deadline) {
  title = (await evalJs("document.title")) ?? "";
  if (title.includes("PASS") || title.includes("FAIL")) break;
  await sleep(500);
}

const lines = await evalJs(
  `[...document.querySelectorAll('#log > div')].map(d => d.textContent).join('\\n')`,
);
if (lines) console.log(lines);
console.log(`title: ${title}`);

kill();
process.exit(title.includes("PASS") ? 0 : 1);
