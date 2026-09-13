# Creating groups

`createGroup` makes the caller the sole member of a new group — epoch 0.
The group object is then used for every subsequent operation.

## `Client::create_group`

| Platform | Signature | Returns |
|----------|-----------|---------|
| Rust | `client.create_group(exts, props, None)` / `create_group_with_id(id, …)` | `Group` |
| Kotlin | `client.createGroup(groupId: ByteArray?)` | `Group` |
| Swift | `client.createGroup(groupId: Data?) throws` | `Group` |
| WASM | `client.createGroup(groupId?: Uint8Array)` | `WasmGroup` |

`groupId`: optional application-chosen identifier. Pass `null`/
`undefined` to let mls-rs generate a random one. The ID is what
`loadGroup` later looks up — record it or use your own scheme.

{{#tabs }}
{{#tab name="Rust" }}

```rust
let group = alice
    .create_group(ExtensionList::new(), Default::default(), None)
    .await?;
// or create_group_with_id(b"chat-42".to_vec(), …)
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
val group = alice.createGroup(null)              // random id
val named = alice.createGroup("chat-42".toByteArray())
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
let group = try alice.createGroup(groupId: nil)
let named = try alice.createGroup(groupId: Data("chat-42".utf8))
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const group = alice.createGroup();               // random id
const named = alice.createGroup(new TextEncoder().encode("chat-42"));
```

{{#endtab }}
{{#endtabs }}

## Notes

* The group's **cipher suite** follows the creator's signing keypair.
* Group state lives in memory until `writeToStorage()` — call it after
  each state change if you want durability (see
  [Persistence](persistence.md)).
* A fresh group has epoch 0 and one member. Adding members moves it to
  epoch 1 — see [Adding members](add_members.md).
