// Shared end-to-end scenarios for the mls-rs WASM bindings.
//
// `wasm` is the imported (already init()ed) package — pass the sync
// build (../pkg) or the async build (../pkg-async); every binding call
// is awaited so the same scenarios exercise both artifacts.
//
// `loadCert` is supplied by the caller: in Node it reads from disk, in
// the browser it fetches over HTTP. It receives a path relative to the
// testbed root, e.g. "test_pki/p256_alice/cert.der".

function assert(cond, msg) {
  if (!cond) throw new Error(`assert failed: ${msg}`);
}

function toArrays(bytesList) {
  return bytesList.map((b) => new Uint8Array(b));
}

const text = new TextEncoder();

export async function runAll(wasm, loadCert, log = console.log) {
  const { WasmCipherSuite, WasmClient, WasmSignatureKeypair } = wasm;

  const ALL_SUITES = [
    WasmCipherSuite.Curve25519Aes128,
    WasmCipherSuite.P256Aes128,
    WasmCipherSuite.Curve25519ChaCha,
    WasmCipherSuite.P521Aes256,
    WasmCipherSuite.P384Aes256,
  ];

  const suiteNames = {
    [WasmCipherSuite.Curve25519Aes128]: "1:Curve25519Aes128",
    [WasmCipherSuite.P256Aes128]: "2:P256Aes128",
    [WasmCipherSuite.Curve25519ChaCha]: "3:Curve25519ChaCha",
    [WasmCipherSuite.P521Aes256]: "5:P521Aes256",
    [WasmCipherSuite.P384Aes256]: "7:P384Aes256",
  };

  async function runBasicSuite(suite) {
    const aliceKey = await wasm.generate_signature_keypair(suite);
    const alice = new WasmClient(text.encode("alice"), aliceKey);
    const bobKey = await wasm.generate_signature_keypair(suite);
    const bob = new WasmClient(text.encode("bob"), bobKey);

    const aliceGroup = await alice.createGroup();
    const bobKeyPackage = await bob.generateKeyPackageMessage();

    const commit = await aliceGroup.addMembers(toArrays([bobKeyPackage]));
    await aliceGroup.processIncomingMessage(commit.commit_message);
    const bobGroup = await bob.joinGroup(commit.welcome_message);

    const ct = await aliceGroup.encryptApplicationMessage(
      text.encode("hello, bob"),
    );
    const received = await bobGroup.processIncomingMessage(ct);
    assert(received.kind === "application", "expected application message");
    assert(
      new TextDecoder().decode(received.data) === "hello, bob",
      "plaintext mismatch",
    );

    // Persistence within the client's storage provider.
    await aliceGroup.writeToStorage();
    await bobGroup.writeToStorage();
  }

  async function runX509(curve, suite, loadCert) {
    const rootCa = new Uint8Array(await loadCert(`test_pki/${curve}_ca/cert.der`));
    const mkClient = async (who) => {
      const cert = new Uint8Array(
        await loadCert(`test_pki/${curve}_${who}/cert.der`),
      );
      const key = JSON.parse(
        new TextDecoder().decode(
          await loadCert(`test_pki/${curve}_${who}/key.json`),
        ),
      );
      const keypair = new WasmSignatureKeypair(
        suite,
        new Uint8Array(key.public_key),
        new Uint8Array(key.secret_key),
      );
      return WasmClient.newX509(toArrays([cert]), toArrays([rootCa]), false, keypair);
    };

    const alice = await mkClient("alice");
    const bob = await mkClient("bob");

    const aliceGroup = await alice.createGroup();
    const commit = await aliceGroup.addMembers(
      toArrays([await bob.generateKeyPackageMessage()]),
    );
    await aliceGroup.processIncomingMessage(commit.commit_message);
    const bobGroup = await bob.joinGroup(commit.welcome_message);

    const ct = await aliceGroup.encryptApplicationMessage(
      text.encode("hello, bob"),
    );
    const received = await bobGroup.processIncomingMessage(ct);
    assert(received.kind === "application", "expected application message");
    assert(
      new TextDecoder().decode(received.data) === "hello, bob",
      "plaintext mismatch",
    );
  }

  async function runRemoval(suite) {
    const alice = new WasmClient(
      text.encode("alice"),
      await wasm.generate_signature_keypair(suite),
    );
    const bob = new WasmClient(
      text.encode("bob"),
      await wasm.generate_signature_keypair(suite),
    );

    const aliceGroup = await alice.createGroup();
    const commit = await aliceGroup.addMembers([await bob.generateKeyPackageMessage()]);
    await aliceGroup.processIncomingMessage(commit.commit_message);
    const bobGroup = await bob.joinGroup(commit.welcome_message);

    // Roster + removal by leaf index — parity with UniFFI removeMembers.
    const members = await aliceGroup.members();
    assert(members.length === 2, `expected 2 members, got ${members.length}`);
    const bobMember = members.find(
      (m) => new TextDecoder().decode(m.identity) === "bob",
    );
    assert(bobMember, "bob not found in roster");

    const removal = await aliceGroup.removeMembers([bobMember.index]);
    await aliceGroup.processIncomingMessage(removal.commit_message);
    const r = await bobGroup.processIncomingMessage(removal.commit_message);
    assert(r.kind === "commit", `expected commit, got ${r.kind}`);
    assert(
      (await aliceGroup.members()).length === 1,
      "bob still present after removal",
    );
  }

  // A device that lost its local group state — but is still in the
  // roster — rejoins by external commit, replacing its stale leaf.
  async function runExternalCommit(suite) {
    const mk = async (who) =>
      new WasmClient(
        text.encode(who),
        await wasm.generate_signature_keypair(suite),
      );
    const alice = await mk("alice");
    const bob = await mk("bob");
    const carol = await mk("carol");

    const aliceGroup = await alice.createGroup();
    const commit = await aliceGroup.addMembers(
      toArrays([
        await bob.generateKeyPackageMessage(),
        await carol.generateKeyPackageMessage(),
      ]),
    );
    await aliceGroup.processIncomingMessage(commit.commit_message);
    const bobGroup = await bob.joinGroup(commit.welcome_message);
    const carolGroup = await carol.joinGroup(commit.welcome_message);

    // bob's device lost its group state: a fresh client for the same
    // credential identity (fresh signature keypair, as a new key
    // package would carry). The GroupInfo is the one the commit
    // itself produced — the blob a delivery service would store.
    assert(
      commit.group_info && commit.group_info.length > 0,
      "commit carried no external-commit GroupInfo",
    );
    const bob2 = await mk("bob");
    const join = await bob2.externalCommit(commit.group_info);
    assert(
      join.removed_leaf_index !== undefined &&
        join.removed_leaf_index !== null,
      "expected a stale-leaf removal",
    );

    // Everyone still in the group applies the external commit.
    await aliceGroup.processIncomingMessage(join.commit_message);
    await carolGroup.processIncomingMessage(join.commit_message);
    await bobGroup.processIncomingMessage(join.commit_message);

    const bob2Group = join.takeGroup();
    const ct = await bob2Group.encryptApplicationMessage(
      text.encode("hello again"),
    );
    const received = await aliceGroup.processIncomingMessage(ct);
    assert(received.kind === "application", "expected application message");
    assert(
      new TextDecoder().decode(received.data) === "hello again",
      "plaintext mismatch",
    );

    // Exactly one leaf per member — bob's stale leaf is gone.
    const members = await aliceGroup.members();
    assert(members.length === 3, `expected 3 members, got ${members.length}`);
    const bobLeaves = members.filter(
      (m) => new TextDecoder().decode(m.identity) === "bob",
    );
    assert(bobLeaves.length === 1, "bob duplicated in roster");
  }

  const X509_SCENARIOS = [
    ["ed25519", WasmCipherSuite.Curve25519Aes128],
    ["ed25519", WasmCipherSuite.Curve25519ChaCha],
    ["p256", WasmCipherSuite.P256Aes128],
    ["p384", WasmCipherSuite.P384Aes256],
    ["p521", WasmCipherSuite.P521Aes256],
  ];

  let failures = 0;

  for (const suite of ALL_SUITES) {
    try {
      await runBasicSuite(suite);
      log(`PASS basic e2e   suite ${suiteNames[suite]}`);
    } catch (e) {
      failures++;
      log(`FAIL basic e2e   suite ${suiteNames[suite]}: ${e}`);
    }
  }

  try {
    await runRemoval(WasmCipherSuite.Curve25519Aes128);
    log("PASS removal+roster suite 1:Curve25519Aes128");
  } catch (e) {
    failures++;
    log(`FAIL removal+roster suite 1: ${e}`);
  }

  try {
    await runExternalCommit(WasmCipherSuite.Curve25519Aes128);
    log("PASS external-commit suite 1:Curve25519Aes128");
  } catch (e) {
    failures++;
    log(`FAIL external-commit suite 1: ${e}`);
  }

  for (const [curve, suite] of X509_SCENARIOS) {
    const label = `x509-${curve}-suite${suiteNames[suite]}`;
    try {
      await runX509(curve, suite, loadCert);
      log(`PASS ${label}`);
    } catch (e) {
      failures++;
      log(`FAIL ${label}: ${e}`);
    }
  }

  if (failures) throw new Error(`${failures} scenario(s) failed`);
  log("All WASM scenarios passed.");
}

// Cross-language wire interop: this client emits its key package as
// raw MLS wire bytes (writeFile), runs the Rust harness to build a
// welcome around all `consumer_kp_*` key packages, then joins the
// group and decrypts the Rust-produced application message.
export async function runInterop(
  wasm,
  { readFixture, writeFixture, runHarness, suiteName, id },
) {
  const { WasmCipherSuite, WasmClient } = wasm;
  const suite = WasmCipherSuite[suiteName];
  assert(suite !== undefined, `unknown suite: ${suiteName}`);

  // Phase 1: emit this client's key package as raw MLS wire bytes.
  const client = new WasmClient(
    text.encode(id),
    await wasm.generate_signature_keypair(suite),
  );
  await writeFixture(
    "consumer_kp_wasm.bin",
    await client.generateKeyPackageMessage(),
  );

  // Phase 2: Rust consumes the key package and produces the welcome.
  await runHarness();

  // Phase 3: join the group from Rust's serialized welcome.
  const group = await client.joinGroup(
    await readFixture("welcome.bin"),
    (await readFixture("ratchet_tree.bin")) ?? undefined,
  );

  // Decrypt the application message Alice sent from Rust.
  const received = await group.processIncomingMessage(await readFixture("app_msg.bin"));
  assert(received.kind === "application", `expected application, got ${received.kind}`);
  const expected = new TextDecoder().decode(await readFixture("plaintext.bin"));
  assert(
    new TextDecoder().decode(received.data) === expected,
    "plaintext mismatch",
  );

  // Roster: alice and this client must both resolve by identity.
  const members = await group.members();
  const decode = (b) => new TextDecoder().decode(b);
  assert(members.length >= 2, `expected >= 2 members, got ${members.length}`);
  assert(members.some((m) => decode(m.identity) === "alice"), "alice not in roster");
  assert(members.some((m) => decode(m.identity) === id), `${id} not in roster`);

  // --- Differential checks against direct-Rust ground truth ---
  // The post-join ratchet tree must byte-match what plain mls-rs
  // computed for the same inputs.
  const eq = (a, b) =>
    a.length === b.length && a.every((v, i) => v === b[i]);
  const treeJoin = await group.exportTree();
  assert(
    eq(treeJoin, await readFixture("expected_tree_join.bin")),
    "post-join tree differs from direct-Rust result",
  );

  // A second commit produced inside plain mls-rs: processing it must
  // drive this client to the identical tree and roster.
  await group.processIncomingMessage(await readFixture("commit2.bin"));
  const treeFinal = await group.exportTree();
  assert(
    eq(treeFinal, await readFixture("expected_tree_final.bin")),
    "post-commit2 tree differs from direct-Rust result",
  );
  const expectedRoster = decode(await readFixture("expected_roster.txt"))
    .split("\n")
    .sort();
  const actualRoster = (await group.members())
    .map((m) => decode(m.identity))
    .sort();
  assert(
    JSON.stringify(actualRoster) === JSON.stringify(expectedRoster),
    `roster mismatch: ${actualRoster} != ${expectedRoster}`,
  );
  const received2 = await group.processIncomingMessage(
    await readFixture("app_msg2.bin"),
  );
  assert(received2.kind === "application", `expected application, got ${received2.kind}`);
  assert(
    decode(received2.data) === decode(await readFixture("plaintext2.bin")),
    "epoch-2 plaintext mismatch",
  );

  // Reverse direction: this binding's encrypted output must be
  // decryptable by the direct Rust library.
  await writeFixture(
    "consumer_msg_wasm.bin",
    await group.encryptApplicationMessage(text.encode("hello from wasm")),
  );
  await runHarness(["--verify"]);
}

// IndexedDB persistence scenarios — browser only (needs a real
// `indexedDB` global). Simulates reloads by opening a second client on
// the same database name + key.
export async function runPersistence(wasm, log = console.log) {
  const { WasmCipherSuite, WasmClient } = wasm;
  const suite = WasmCipherSuite.Curve25519Aes128;
  const name = `test-${Math.random().toString(36).slice(2)}`;
  const storageKey = new Uint8Array(32);
  globalThis.crypto.getRandomValues(storageKey);
  const wrongKey = new Uint8Array(32);
  globalThis.crypto.getRandomValues(wrongKey);

  const decode = (b) => new TextDecoder().decode(b);
  let failures = 0;
  const check = async (label, fn) => {
    try {
      await fn();
      log(`PASS persistence: ${label}`);
    } catch (e) {
      failures++;
      log(`FAIL persistence: ${label}: ${e}`);
    }
  };

  try {
    await check("group state survives reload", async () => {
      const groupId = text.encode("g1");
      const alice = await WasmClient.openPersistent(
        name,
        text.encode("alice"),
        await wasm.generate_signature_keypair(suite),
        storageKey,
      );
      const group = await alice.createGroup(groupId);
      await group.writeToStorage();
      await alice.flushStorage();

      // "Reload": a fresh client hydrates from IndexedDB.
      const alice2 = await WasmClient.openPersistent(
        name,
        text.encode("alice"),
        await wasm.generate_signature_keypair(suite),
        storageKey,
      );
      const group2 = await alice2.loadGroup(groupId);
      await group2.encryptApplicationMessage(text.encode("after reload"));
      assert((await group2.members()).length === 1, "member lost on reload");
      alice.close();
      alice2.close();
    });

    await check("key package stays joinable across reload", async () => {
      // Carol publishes a key package, then "restarts". Mallory adds
      // her using that pre-reload key package — the HPKE init key must
      // have been persisted for the join to succeed.
      const carolName = `${name}-carol`;
      const carolKeypair = await wasm.generate_signature_keypair(suite);
      const carol = await WasmClient.openPersistent(
        carolName,
        text.encode("carol"),
        carolKeypair,
        storageKey,
      );
      const kp = await carol.generateKeyPackageMessage();
      await carol.flushStorage();

      // Reload carol — same keypair (app-held), same storage.
      const carol2 = await WasmClient.openPersistent(
        carolName,
        text.encode("carol"),
        carolKeypair,
        storageKey,
      );

      const mallory = new WasmClient(
        text.encode("mallory"),
        await wasm.generate_signature_keypair(suite),
      );
      const group = await mallory.createGroup();
      const commit = await group.addMembers([kp]);
      const carolGroup = await carol2.joinGroup(commit.welcome_message);
      assert(
        (await carolGroup.members()).length === 2,
        "carol could not join with a pre-reload key package",
      );
      carol.close();
      carol2.close();
    });

    await check("wrong storage key fails closed", async () => {
      let opened = null;
      try {
        opened = await WasmClient.openPersistent(
          name,
          text.encode("alice"),
          await wasm.generate_signature_keypair(suite),
          wrongKey,
        );
      } catch {
        return; // rejected at hydrate — expected
      }
      throw new Error("openPersistent accepted a wrong key");
    });

    await check("delete removes all state", async () => {
      // Fresh client on `name`, close every connection, then delete.
      const alice3 = await WasmClient.openPersistent(
        name,
        text.encode("alice"),
        await wasm.generate_signature_keypair(suite),
        storageKey,
      );
      await alice3.flushStorage();
      alice3.close();
      await WasmClient.deletePersistentStorage(name);

      const alice4 = await WasmClient.openPersistent(
        name,
        text.encode("alice"),
        await wasm.generate_signature_keypair(suite),
        storageKey,
      );
      let threw = false;
      try {
        await alice4.loadGroup(text.encode("g1"));
      } catch {
        threw = true;
      }
      assert(threw, "group still loadable after delete");
      alice4.close();
    });
  } finally {
    // Best-effort cleanup so repeated runs don't accumulate DBs.
    try {
      await WasmClient.deletePersistentStorage(name);
      await WasmClient.deletePersistentStorage(`${name}-carol`);
    } catch {}
  }

  if (failures) throw new Error(`${failures} persistence scenario(s) failed`);
  log("All persistence scenarios passed.");
}
