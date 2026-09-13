# Commits & epochs

A **commit** ratchets the group forward one **epoch**: it applies all
pending proposals, updates the committer's leaf key material (fresh
HPKE keys → post-compromise healing) and produces the messages to fan
out.

## `Group::commit`

| Platform | Signature | Returns |
|----------|-----------|---------|
| Rust | `group.commit(vec![])` | `CommitOutput` |
| Kotlin | `group.commit()` | `CommitOutput` |
| Swift | `group.commit() throws` | `CommitOutput` |
| WASM | `group.commit()` | `WasmCommitOutput` |

{{#tabs }}
{{#tab name="Rust" }}

```rust
let out = group.commit(vec![]).await?;   // empty commit = self-update
fan_out(out.commit_message);
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
val out = group.commit()
sendToMembers(out.commitMessage)
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
let out = try group.commit()
sendToMembers(out.commitMessage)
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const out = group.commit();
sendToMembers(out.commit_message);
```

{{#endtab }}
{{#endtabs }}

An **empty commit** (no proposals) still rotates the committer's key —
call it after a suspected compromise or on a schedule for PCS.

## `CommitEffect` — what a processed commit did

When a member processes a commit message, `ReceivedMessage.Commit`
carries an effect:

| Variant | Meaning |
|---------|---------|
| `NewEpoch(appliedProposals, unusedProposals)` | normal epoch advance; lists which pending proposals made it in |
| `ReInit` | the group re-initialized (protocol/config change) |
| `Removed` | **you** were removed — discard local state |

## Epoch semantics

* Epochs are sequential (`0, 1, 2, …`); each epoch has its own key
  schedule and secrets.
* Commits are serialized — delivery services must not reorder them.
* Old epoch secrets are retained per your `GroupStateStorage`
  implementation (needed to decrypt straggling messages); prune epochs
  in `write()` if you want bounded history — see
  [Persistence](persistence.md).
