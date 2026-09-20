# Joining via external commit

An **external commit** joins a group without a Welcome: the joiner
fetches the group's public `GroupInfo`, builds a commit that adds its
own leaf, and the group treats that commit as ordinary control
traffic. No existing member has to be online — the joiner repairs
itself.

The canonical use is **self-repair**: a device lost its local group
state but its leaf is still in the roster. When the joiner's
credential matches a leaf already in the tree, `externalCommit`
removes that stale leaf inside the same commit — one commit replaces
the leaf and rejoins the device. If no leaf matches, this is a plain
external join.

## Step 1 — a member exports `GroupInfo`

Any current member produces the public `GroupInfo` blob a joiner
needs. Pass `withTreeInExtension = true` to embed the ratchet tree so
the joiner needs nothing else; pass `false` when the delivery service
distributes the tree separately (then the joiner must supply
`ratchetTree`).

| Platform | Signature | Returns |
|----------|-----------|---------|
| Kotlin | `group.groupInfoMessageAllowingExtCommit(withTreeInExtension)` | `Message` |
| Swift | `group.groupInfoMessageAllowingExtCommit(withTreeInExtension:) throws` | `Message` |
| WASM | `group.groupInfoForExternalCommit(withTree)` | `Uint8Array` |

Publish the result through your delivery service (e.g. an HTTP
endpoint keyed by group + epoch). GroupInfo is epoch-bound — a stale
one fails commit validation, so refresh it after every commit.

## Step 2 — the joiner commits externally

| Platform | Signature | Returns |
|----------|-----------|---------|
| Rust | `client.external_commit_builder().with_removal(i).build(gi)` | `(Group, MlsMessage)` |
| Kotlin | `client.externalCommit(groupInfo, treeData)` | `ExternalJoinInfo` |
| Swift | `client.externalCommit(groupInfo:treeData:) throws` | `ExternalJoinInfo` |
| WASM | `client.externalCommit(groupInfoBytes, treeBytes?)` | `WasmExternalJoinInfo` |

{{#tabs }}
{{#tab name="Kotlin" }}

```kotlin
val groupInfo: Message = fetchGroupInfo(groupId)          // from your DS
val join = client.externalCommit(groupInfo, treeData = null)

sendToMembers(join.commitMessage)                          // fan out like any commit
val group: Group = join.group
join.removedLeafIndex?.let { log("replaced stale leaf $it") }
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
let groupInfo: Message = try await fetchGroupInfo(groupId) // from your DS
let join = try client.externalCommit(groupInfo: groupInfo, treeData: nil)

sendToMembers(join.commitMessage)                          // fan out like any commit
let group = join.group
if let removed = join.removedLeafIndex { log("replaced stale leaf \(removed)") }
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const join = await client.externalCommit(groupInfoBytes);   // tree embedded
sendToMembers(join.commit_message);
const group = join.takeGroup();                             // consumes — call once
console.log("replaced stale leaf", join.removed_leaf_index);
```

{{#endtab }}
{{#endtabs }}

## `ExternalJoinInfo`

| Field | Type | Meaning |
|-------|------|---------|
| `group` | `Group` / `WasmGroup` | the joined group — usable immediately |
| `commitMessage` | `Message` / `Uint8Array` | the external commit — **must be fanned out** to all members like any commit |
| `removedLeafIndex` | `UInt32?` | the stale leaf that was removed, when a same-credential leaf existed |

WASM spells the fields `commit_message` / `removed_leaf_index`, and
`group` is consumed once via `takeGroup()`.

## Notes & errors

* **Fan out the commit.** Until members process it they are on the old
  epoch; ciphertext they send in between will not decrypt for you.
* **Epoch binding.** The GroupInfo is valid for one epoch. If a
  concurrent commit lands first, the build fails — refetch and retry.
* **Credential matching is exact.** Basic credentials match by
  identity bytes; a fresh signature keypair still matches (that is the
  repair case — new keys replace the old leaf). X.509 credentials
  match on the full credential.
* **Not a member?** With no same-credential leaf, the commit adds you
  as a *new* member — but only if the group's delivery service
  actually routes your commit to members; MLS itself does not gate who
  may submit an external commit.
* `removedLeafIndex` is `null`/`undefined` for a plain join — use it
  to tell "self-repair" from "new joiner" in logs and delivery-service
  authorization.
