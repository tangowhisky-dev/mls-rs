# Adding members

Two ways: **immediate** (`addMembers` — propose + commit in one call)
or **two-phase** (`proposeAddMembers` then a later `commit`). Both move
the group to a new epoch; the commit produces a Welcome for the new
members.

## Immediate: `add_members`

| Platform | Signature | Returns |
|----------|-----------|---------|
| Rust | `group.commit_builder().add_member(kp)….build()` | `CommitOutput` |
| Kotlin | `group.addMembers(keyPackages: List<Message>)` | `CommitOutput` |
| Swift | `group.addMembers(keyPackages: [Message]) throws` | `CommitOutput` |
| WASM | `group.addMembers(keyPackages: Uint8Array[])` | `WasmCommitOutput` |

{{#tabs }}
{{#tab name="Rust" }}

```rust
let out = group.commit_builder()
    .add_member(bob_key_package)
    .add_member(carol_key_package)
    .build().await?;
fan_out(out.commit_message);                    // to all existing members
deliver(out.welcome_messages[0], new_members);  // to the joiners only
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
val bobKp = Message.fromBytes(bobKpBytes)    // key package off the wire
val commit: CommitOutput = aliceGroup.addMembers(listOf(bobKp))
sendToMembers(commit.commitMessage.toBytes())          // to existing members
commit.welcomeMessage?.let { sendToNewMember(it.toBytes()) }
commit.ratchetTree?.let { sendOutOfBand(it.bytes) }   // if extension off
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
let bobKp = try Message.fromBytes(bytes: bobKpBytes)
let commit = try aliceGroup.addMembers(keyPackages: [bobKp])
sendToMembers(try commit.commitMessage.toBytes())
if let welcome = commit.welcomeMessage {
    sendToNewMember(try welcome.toBytes())
}
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const commit = aliceGroup.addMembers([bobKeyPackageBytes]);
sendToMembers(commit.commit_message);
if (commit.welcome_message) sendToNewMember(commit.welcome_message);
if (commit.ratchet_tree) sendTreeOutOfBand(commit.ratchet_tree);
```

{{#endtab }}
{{#endtabs }}

`CommitOutput` fields: `commitMessage` (always), `welcomeMessage`
(present only when members were added), `ratchetTree` (when the
ratchet-tree extension is off), `groupInfo` (for external-commit
bootstrap). Full field reference: [Data types](types.md).

## Two-phase: `propose_add_members` + `commit`

Proposals let members *suggest* a change without committing — another
member (or the same one) later commits pending + received proposals.

{{#tabs }}
{{#tab name="Rust" }}

```rust
let proposal = group.propose_add(bob_key_package, vec![]).await?;
fan_out(proposal);                      // proposal message to the group
let out = group.commit(vec![]).await?;  // commits pending proposals
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
val proposals: List<Message> = aliceGroup.proposeAddMembers(listOf(bobKp))
proposals.forEach { sendToMembers(it.toBytes()) }
val commit = aliceGroup.commit()       // or any other member commits
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
let proposals = try aliceGroup.proposeAddMembers(keyPackages: [bobKp])
for p in proposals { sendToMembers(try p.toBytes()) }
let commit = try aliceGroup.commit()
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const proposals = aliceGroup.proposeAddMembers([bobKpBytes]);
for (const p of proposals) sendToMembers(p);
const commit = aliceGroup.commit();
```

{{#endtab }}
{{#endtabs }}

## Rules

* Key packages are validated on add: cipher-suite match, credential
  validity (X.509 chains checked against your root CAs), lifetime.
* The committer must process their own commit too — `processIncomingMessage(commitMessage)` — the testbeds do this; some apps fold it into the same send path.
* One commit may add several members — one welcome per group, or per
  member depending on `singleWelcomeMessage` (on → single welcome).
