# Joining groups

A new member joins from a **Welcome** message produced by an
`addMembers` commit. The welcome is encrypted to the new member's key
package — only they can read it.

> Lost your local group state but your leaf is still in the roster?
> Don't wait for a new welcome — see
> [Joining via external commit](external_commit.md) for self-repair.

## `Client::join_group`

| Platform | Signature | Returns |
|----------|-----------|---------|
| Rust | `client.join_group(tree, &welcome, None)` | `(Group, NewMemberInfo)` |
| Kotlin | `client.joinGroup(ratchetTree, welcomeMessage)` | `JoinInfo{group, groupInfoExtensions}` |
| Swift | `client.joinGroup(ratchetTree:, welcomeMessage:) throws` | `JoinInfo` |
| WASM | `client.joinGroup(welcome, ratchetTree?)` | `WasmGroup` |

## Parameters

| Param | Type | Meaning |
|-------|------|---------|
| `welcomeMessage` | `Message` / `Uint8Array` | the welcome delivered to this client |
| `ratchetTree` | `RatchetTree?` / `Uint8Array?` | serialized tree — **required only if** the group was created with `useRatchetTreeExtension = false`; pass `null`/`undefined` when the welcome already carries the tree (the default) |

{{#tabs }}
{{#tab name="Rust" }}

```rust
let tree = ratchet_tree_bytes
    .map(|b| ExportedTree::from_bytes(&b)).transpose()?;
let (group, new_member_info) = bob.join_group(tree, &welcome, None).await?;
// new_member_info.group_info_extensions: extensions placed by the committer
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
val info = bob.joinGroup(ratchetTree = null, welcomeMessage = welcome)
val group: Group = info.group
val exts: ExtensionList = info.groupInfoExtensions
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
let info = try bob.joinGroup(ratchetTree: nil, welcomeMessage: welcome)
let group = info.group
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const group = bob.joinGroup(welcomeBytes);            // tree in welcome
const group2 = bob.joinGroup(welcomeBytes, treeBytes); // out-of-band tree
```

{{#endtab }}
{{#endtabs }}

## The key-package storage caveat

The welcome is encrypted to your key package's **HPKE init private
key**, which lives in the client's key-package storage — written when
`generateKeyPackageMessage()` ran. The UniFFI and WASM clients keep
this storage in memory, so a welcome can only be joined by the **same
client instance** that generated the referenced key package. After an
app restart, publish a fresh key package rather than reusing a stale
one. (Rust apps can supply a persistent `key_package_repo` if they
need joins across restarts.)

## Errors

* malformed welcome → decode/parse error
* wrong/missing ratchet tree → `InvalidJoin`/`tree` errors
* expired or mismatched key package → the join fails validation
* X.509 chains in the group are validated against *your*
  `rootCaCertificates` during join — unknown roots are rejected.

## Examining a welcome

`processIncomingMessage(welcome)` on a group-less context isn't needed —
joining validates it. In Kotlin/Swift `ReceivedMessage.Welcome` exists
for members that *process* a welcome fan-out (mostly informational).
