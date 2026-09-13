# Persistence & tree export

MLS state is not durable by magic — you decide when and where it lands.

## The write/load cycle

| Operation | Call |
|-----------|------|
| Save | `group.writeToStorage()` — after every state change (join, commit processed, message sent) |
| Reload | `client.loadGroup(groupId)` — returns a `Group` for the stored id |

{{#tabs }}
{{#tab name="Rust" }}

```rust
group.write_to_storage().await?;
let reloaded = client.load_group(&group_id).await?;
```

Storage is pluggable: `InMemoryGroupStateStorage` (default),
`mls-rs-provider-sqlite`'s `SqliteStorage`, or your own
`GroupStateStorage` impl.

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
group.writeToStorage()
val reloaded = client.loadGroup(groupId)
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
try group.writeToStorage()
let reloaded = try client.loadGroup(groupId: groupId)
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
await group.writeToStorage();
await client.flushStorage();                    // sync artifact: settle background writes
const reloaded = await client.loadGroup(groupIdBytes);
```

Persistence across reloads needs `WasmClient.openPersistent(name, id,
keypair, storageKey)` — group state, epoch secrets and key-package
init keys land in IndexedDB, AES-256-GCM encrypted under the app's
32-byte `storageKey` (see
[app setup](../manual/app_setup.md#storage-service)). Clients created
with `new WasmClient(...)` remain in-memory only.

{{#endtab }}
{{#endtabs }}

## Implementing `GroupStateStorage` (Kotlin/Swift callback)

Provide an object implementing this interface in `ClientConfig`:

| Method | Parameters | Return | Called when |
|--------|-----------|--------|-------------|
| `state` | `groupId` | `ByteArray?` — serialized group snapshot | loading a group |
| `epoch` | `groupId`, `epochId` | `ByteArray?` — that epoch's secrets | processing straggler messages from an older epoch |
| `write` | `groupId`, `groupState`, `epochInserts`, `epochUpdates` | — | `writeToStorage()` / internal checkpoints |
| `maxEpochId` | `groupId` | `UInt64?` — newest stored epoch | startup / consistency checks |

`EpochRecord{id, data}` pairs an epoch number with its secret blob —
insert new ones, update in place when `epochUpdates` arrive, delete old
ones if you want bounded retention.

{{#tabs }}
{{#tab name="Kotlin" }}

```kotlin
class SqlStorage(val db: MyDb) : GroupStateStorage {
    override fun state(groupId: ByteArray) =
        db.get(groupId)?.state
    override fun epoch(groupId: ByteArray, epochId: ULong) =
        db.epoch(groupId, epochId.toLong())
    override fun write(groupId: ByteArray, state: ByteArray,
                       inserts: List<EpochRecord>, updates: List<EpochRecord>) =
        db.upsert(groupId, state, inserts, updates)
    override fun maxEpochId(groupId: ByteArray) =
        db.maxEpoch(groupId)?.toULong()
}
val config = clientConfigDefault().copy(groupStateStorage = SqlStorage(db))
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
final class DiskStorage: GroupStateStorage {
    func state(groupId: Data) throws -> Data? { … }
    func epoch(groupId: Data, epochId: UInt64) throws -> Data? { … }
    func write(groupId: Data, groupState: Data,
               epochInserts: [EpochRecord], epochUpdates: [EpochRecord]) throws { … }
    func maxEpochId(groupId: Data) throws -> UInt64? { … }
}
var config = clientConfigDefault()
config.groupStateStorage = DiskStorage()
```

{{#endtab }}
{{#endtabs }}

## `exportTree` — the ratchet tree out of band

| Platform | Returns |
|----------|---------|
| Kotlin | `group.exportTree(): RatchetTree` |
| Swift | `group.exportTree() throws -> RatchetTree` |
| WASM | `group.exportTree() -> Uint8Array` |

Needed when `useRatchetTreeExtension = false`: hand the exported bytes
to joiners alongside the welcome (see
[Joining groups](join_group.md)). `RatchetTree{bytes}` is just a
serialized `ExportedTree` wrapper.
