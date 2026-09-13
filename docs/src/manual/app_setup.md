# Wiring MLS into your app

The library handles MLS cryptography; your app owns three things around
it: **client identity**, **storage** and **transport** (the delivery
service). This page shows a complete per-platform setup.

## The moving parts

```text
┌─────────────────────────── your app ────────────────────────────┐
│  MlsService                                                     │
│   ├─ Client          (one per user identity, created at startup)│
│   ├─ GroupStateStorage impl  → SQLite / files / CoreData        │
│   └─ DeliveryService impl    → your server (dumb relay)         │
│        publishKeyPackage / fetchKeyPackages / fanout / fetch    │
└─────────────────────────────────────────────────────────────────┘
```

The delivery server is intentionally dumb — it stores and forwards
opaque bytes, never parses MLS. Ordering rule: commits for a group
must be delivered in epoch order; add a per-group sequence number in
your envelope.

## Storage service

The binding calls your `GroupStateStorage` whenever group state
changes. A minimal but correct implementation is a directory of files
— production apps typically back it with Room/SQLite/CoreData instead;
the interface stays identical.

{{#tabs }}
{{#tab name="Rust" }}

```rust
// Rust: use mls-rs-provider-sqlite directly — no glue needed.
use mls_rs_provider_sqlite::SqliteStorage;
let storage = SqliteStorage::new("mls.sqlite")?; // durable
// or: InMemoryGroupStateStorage::new()         // ephemeral
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
class FileStorage(private val dir: File) : GroupStateStorage {
    private fun hex(b: ByteArray) = b.joinToString("") { "%02x".format(it) }
    private fun file(id: ByteArray, suffix: String) =
        File(dir, hex(id) + suffix)

    override fun state(groupId: ByteArray): ByteArray? =
        file(groupId, ".state").takeIf { it.exists() }?.readBytes()

    override fun epoch(groupId: ByteArray, epochId: ULong): ByteArray? =
        file(groupId, ".epoch.$epochId").takeIf { it.exists() }?.readBytes()

    override fun write(
        groupId: ByteArray, groupState: ByteArray,
        epochInserts: List<EpochRecord>, epochUpdates: List<EpochRecord>,
    ) {
        file(groupId, ".state").writeBytes(groupState)
        for (r in epochInserts) file(groupId, ".epoch.${r.id}").writeBytes(r.data)
        for (r in epochUpdates) file(groupId, ".epoch.${r.id}").writeBytes(r.data)
    }

    override fun maxEpochId(groupId: ByteArray): ULong? =
        dir.list { n, _ -> n.startsWith(hex(groupId) + ".epoch.") }
            ?.mapNotNull { it.substringAfterLast('.').toULongOrNull() }
            ?.maxOrNull()
}
// usage: clientConfigDefault().copy(groupStateStorage = FileStorage(dir))
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
final class FileStorage: GroupStateStorage {
    let dir: URL
    init(dir: URL) { self.dir = dir }
    private func file(_ id: Data, _ suffix: String) -> URL {
        dir.appendingPathComponent(id.map { String(format: "%02x", $0) }.joined() + suffix)
    }

    func state(groupId: Data) throws -> Data? {
        try? Data(contentsOf: file(groupId, ".state"))
    }
    func epoch(groupId: Data, epochId: UInt64) throws -> Data? {
        try? Data(contentsOf: file(groupId, ".epoch.\(epochId)"))
    }
    func write(groupId: Data, groupState: Data,
               epochInserts: [EpochRecord], epochUpdates: [EpochRecord]) throws {
        try groupState.write(to: file(groupId, ".state"), options: .atomic)
        for r in epochInserts + epochUpdates {
            try r.data.write(to: file(groupId, ".epoch.\(r.id)"), options: .atomic)
        }
    }
    func maxEpochId(groupId: Data) throws -> UInt64? { nil } // or scan dir
}
// usage: var c = clientConfigDefault(); c.groupStateStorage = FileStorage(dir: dir)
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

The WASM wrapper implements storage for you — the
[Wire](https://github.com/wireapp/core-crypto) pattern: an
IndexedDB-backed store holding **MLS state only** (group snapshots,
epoch secrets, key-package init keys), with every value AES-256-GCM
encrypted under an application-supplied key:

```js
// One-time: generate a 32-byte storage key and persist it however
// your app keeps secrets (WebCrypto non-extractable key, platform
// keystore via a companion, passphrase-derived…). Losing it loses all
// stored MLS state; changing it makes stored data unreadable.
const storageKey = /* 32 bytes, app-managed */;

const client = await WasmClient.openPersistent(
  "device-1",                // database name → `mls-rs-device-1`
  text.encode("alice"),      // basic credential identity
  keypair,                   // signature keypair (store its bytes too)
  storageKey,
);
await group.writeToStorage();
await client.flushStorage(); // settle write-behind commits

// After a reload:
const again = await WasmClient.openPersistent("device-1", id, keypair, storageKey);
const group2 = await again.loadGroup(groupId);   // works — state survived
```

Key facts:

* `WasmClient.openPersistentX509` is the X.509 equivalent (same
  parameters as `newX509` plus `name`/`storageKey`).
* The store is **MLS-only** — app data (messages, contacts, UI state)
  stays in your own storage; nothing crosses into the MLS database.
* A wrong `storageKey` fails closed at open (AES-GCM tag mismatch);
  a *fresh* empty database opens fine under any key.
* `WasmClient.deletePersistentStorage(name)` deletes the database —
  `client.close()` open clients first (IndexedDB blocks deletes while
  connections are open).
* In the **sync artifact** (`pkg/`) writes commit to IndexedDB in the
  background — call `flushStorage()` before unload or before handing a
  just-sent commit's ciphertext to the network. In the **async
  artifact** (`pkg-async/`) every storage write is awaited inside the
  call itself.

{{#endtab }}
{{#endtabs }}

`epochInserts`/`epochUpdates` exist so the client can still process
**straggler messages** that arrive from an older epoch (e.g. a commit
racing with your message). Keep at least the last few epochs; delete
older ones if you need bounded storage.

## Delivery service

Shape it however your backend works — REST, WebSocket, push — but it
needs these four verbs. All payloads are the raw MLS wire bytes.

{{#tabs }}
{{#tab name="Kotlin" }}

```kotlin
interface DeliveryService {
    suspend fun publishKeyPackage(kp: ByteArray)
    suspend fun fetchKeyPackages(userId: ByteArray): List<ByteArray>
    suspend fun sendCommit(groupId: ByteArray, commit: ByteArray,
                           welcomes: Map<ByteArray, ByteArray>) // userId→welcome
    suspend fun sendApplication(groupId: ByteArray, ct: ByteArray)
    suspend fun poll(groupId: ByteArray): List<ByteArray>       // ordered inbox
}
// The server stores bytes per group and delivers in commit order.
// It never needs to parse MLS — only mls-rs does.
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
protocol DeliveryService {
    func publishKeyPackage(_ kp: Data) async throws
    func fetchKeyPackages(_ userId: Data) async throws -> [Data]
    func sendCommit(groupId: Data, commit: Data,
                    welcomes: [Data: Data]) async throws
    func sendApplication(groupId: Data, _ ct: Data) async throws
    func poll(groupId: Data) async throws -> [Data]
}
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
// Implement against your backend — all values are Uint8Array.
const delivery = {
  publishKeyPackage: (kp) => api.post("/keypackages", kp),
  fetchKeyPackages: (userId) => api.get(`/keypackages/${b64(userId)}`),
  sendCommit: (gid, commit, welcomes) => api.post(`/g/${b64(gid)}/commit`, {commit, welcomes}),
  sendApplication: (gid, ct) => api.post(`/g/${b64(gid)}/msg`, ct),
  poll: (gid) => api.get(`/g/${b64(gid)}/inbox`),
};
```

{{#endtab }}
{{#tab name="Rust" }}

```rust
#[async_trait::async_trait]
pub trait DeliveryService {
    async fn publish_key_package(&self, kp: &[u8]);
    async fn fetch_key_packages(&self, user: &[u8]) -> Vec<Vec<u8>>;
    async fn send_commit(&self, gid: &[u8], commit: &[u8],
                         welcomes: &[(Vec<u8>, Vec<u8>)]);
    async fn send_application(&self, gid: &[u8], ct: &[u8]);
    async fn poll(&self, gid: &[u8]) -> Vec<Vec<u8>>;
}
```

{{#endtab }}
{{#endtabs }}

Ordering contract your server must honor:

1. Key packages are fetched before use — a directory lookup per user.
2. Commits apply in epoch order; number them per group (`gid, epoch`)
   and deliver in that order. mls-rs rejects out-of-order commits.
3. A welcome goes **only** to the users it was issued for — the bytes
   are encrypted to them, so per-recipient delivery is both correct
   and private.
4. Senders don't need their own message back — but committing members
   must still *process* their own commit locally
   (`processIncomingMessage(commitMessage)`).

## Startup sequence

{{#tabs }}
{{#tab name="Kotlin" }}

```kotlin
class MlsService(ctx: Context, val userId: ByteArray) {
    private val storage = FileStorage(File(ctx.filesDir, "mls"))
    private val client: Client
    private val groups = mutableMapOf<ByteArray, Group>()

    init {
        // Reuse a persisted signature keypair if you stored one; else
        // generate once and persist the raw bytes yourself (e.g. in
        // EncryptedSharedPreferences / Keystore-backed storage).
        val keypair = loadOrCreateKeypair(CipherSuite.CURVE25519_AES128)
        val config = clientConfigDefault().copy(groupStateStorage = storage)
        client = Client(userId, keypair, config)
    }

    suspend fun group(gid: ByteArray): Group =
        groups.getOrPut(gid.toList()) { client.loadGroup(gid) }

    suspend fun sync(gid: ByteArray) = withContext(Dispatchers.IO) {
        for (bytes in delivery.poll(gid))
            groups[gid.toList()]?.processIncomingMessage(Message.fromBytes(bytes))
    }
}
// IMPORTANT: all calls are synchronous — always wrap in
// Dispatchers.IO (or build an async artifact, see interoperability.md).
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
final class MlsService {
    let client: Client
    init(userId: Data, storageDir: URL) throws {
        let keypair = try loadOrCreateKeypair(.curve25519Aes128) // persist bytes in Keychain
        var config = clientConfigDefault()
        config.groupStateStorage = FileStorage(dir: storageDir)
        client = try Client(id: userId, signatureKeypair: keypair,
                            clientConfig: config)
    }
    // Calls block — invoke from a Task / background queue, or build
    // with --cfg mls_build_async for `async` methods.
}
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
import init, { WasmClient, WasmCipherSuite, generate_signature_keypair }
  from "./pkg/mls_rs_wasm.js";

await init();
// Persist the keypair bytes yourself (e.g. IndexedDB); a fresh
// keypair each session also works but orphan key packages accrue.
const keypair = generate_signature_keypair(WasmCipherSuite.Curve25519Aes128);
const client = new WasmClient(new TextEncoder().encode(userId), keypair);
// Groups live in memory for the session.
```

{{#endtab }}
{{#tab name="Rust" }}

```rust
let storage = SqliteStorage::new("mls.sqlite")?;
let client = Client::builder()
    .crypto_provider(RustCryptoProvider::default())
    .identity_provider(BasicIdentityProvider::new())
    .signing_identity(signing_identity, secret_key, cipher_suite)
    .group_state_storage(storage.into())
    .build();
```

{{#endtab }}
{{#endtabs }}

## The complete message loop

Putting it together — this is the shape every app converges on:

```text
startup:   client ← storage ← persisted keypair
publish:   generateKeyPackageMessage().toBytes() → delivery.publish
add:       fetchKeyPackages(bob) → Message.fromBytes → addMembers
           → sendCommit(commit.toBytes(), welcome.toBytes())
join:      poll welcome → Message.fromBytes → joinGroup → writeToStorage
chat:      encryptApplicationMessage → toBytes → sendApplication
receive:   poll → fromBytes → processIncomingMessage → writeToStorage
```

Verify the wiring with `platform_testbeds/scripts/test_interop.sh`
before involving a real server — it exercises the exact same byte
exchange across all four platforms.
