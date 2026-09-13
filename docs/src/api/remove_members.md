# Removing members

Members are removed by **identity** (Kotlin/Swift) or **leaf index**
(WASM). Obtain a `SigningIdentity` from `group.members()`,
`group.memberWithIdentity(id)`, `client.signingIdentity()`, or the
`sender` field of a received message — or reconstruct one out of band
with `SigningIdentity.newBasic(id, publicKey)` /
`SigningIdentity.newX509(certChain, publicKey)` (e.g. to remove a
member you've never received a message from). WASM exposes the leaf
index on `WasmMember.index` instead.

## Immediate: `remove_members`

| Platform | Signature | Returns |
|----------|-----------|---------|
| Rust | `group.commit_builder().remove_member(index)…build()` | `CommitOutput` |
| Kotlin | `group.removeMembers(signingIdentities: List<SigningIdentity>)` | `CommitOutput` |
| Swift | `group.removeMembers(signingIdentities: [SigningIdentity]) throws` | `CommitOutput` |
| WASM | `group.removeMembers(indexes: Uint32Array-like)` | `WasmCommitOutput` |

{{#tabs }}
{{#tab name="Rust" }}

```rust
let member = group.member_with_identity(bob_identifier).await?;
let out = group.commit_builder()
    .remove_member(member.index)
    .build().await?;
fan_out(out.commit_message);
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
// From the roster…
val bobIdentity = aliceGroup.memberWithIdentity("bob".toByteArray())
// …from a received message's `sender`, or reconstructed out of band:
val reconstructed = SigningIdentity.newBasic("bob".toByteArray(), bobPublicKey)
val commit = aliceGroup.removeMembers(listOf(bobIdentity))
sendToMembers(commit.commitMessage.toBytes())   // includes Bob — he sees he's removed
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
let bobIdentity = try aliceGroup.memberWithIdentity(
    identifier: Data("bob".utf8))
// or: SigningIdentity.newBasic(id: Data("bob".utf8), publicKey: bobPublicKey)
let commit = try aliceGroup.removeMembers(signingIdentities: [bobIdentity])
sendToMembers(try commit.commitMessage.toBytes())
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const member = group.members().find(
    (m) => new TextDecoder().decode(m.identity) === "bob");
const commit = group.removeMembers([member.index]);  // by leaf index
sendToMembers(commit.commit_message);
```

{{#endtab }}
{{#endtabs }}

## Two-phase: `propose_remove_members` + `commit`

{{#tabs }}
{{#tab name="Rust" }}

```rust
let proposal = group.propose_remove(member.index, vec![]).await?;
fan_out(proposal);
let out = group.commit(vec![]).await?;
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
val proposals = aliceGroup.proposeRemoveMembers(listOf(bobIdentity))
proposals.forEach { sendToMembers(it) }
val commit = aliceGroup.commit()
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
let proposals = try aliceGroup.proposeRemoveMembers(
    signingIdentities: [bobIdentity])
for p in proposals { sendToMembers(p) }
let commit = try aliceGroup.commit()
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const proposals = group.proposeRemoveMembers([member.index]);
for (const p of proposals) sendToMembers(p);
const commit = group.commit();
```

{{#endtab }}
{{#endtabs }}

## Being removed

The removed member still processes the commit: `processIncomingMessage`
returns `ReceivedMessage.Commit` whose `effect` is
`CommitEffect.Removed` — your cue to discard the group locally. Removed
members can no longer decrypt subsequent messages (post-removal forward
secrecy).
