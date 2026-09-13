# Processing incoming messages

One entry point for everything inbound: `processIncomingMessage`. Feed
it every message the delivery service hands you — commits, proposals,
ciphertexts, welcomes, key packages — and it validates, applies and
classifies them.

## `Group::process_incoming_message`

| Platform | Signature | Returns |
|----------|-----------|---------|
| Rust | `group.process_incoming_message(msg)` | `ReceivedMessage` |
| Kotlin | `group.processIncomingMessage(message: Message)` | `ReceivedMessage` |
| Swift | `group.processIncomingMessage(message: Message) throws` | `ReceivedMessage` |
| WASM | `group.processIncomingMessage(message: Uint8Array)` | `WasmReceivedMessage` |

## `ReceivedMessage` variants

{{#tabs }}
{{#tab name="Rust" }}

```rust
match group.process_incoming_message(msg).await? {
    ReceivedMessage::ApplicationMessage(m) =>
        handle(m.data(), m.sender_index),
    ReceivedMessage::Commit(c) =>
        handle_effect(c.committer, c.effect), // NewEpoch/ReInit/Removed
    ReceivedMessage::Proposal(p) => { /* stored pending proposal */ }
    ReceivedMessage::GroupInfo(_) => { /* validated group info */ }
    ReceivedMessage::Welcome => { /* validated welcome */ }
    ReceivedMessage::KeyPackage(_) => { /* validated key package */ }
}
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
val msg = Message.fromBytes(wireBytes)   // parse transport bytes first
when (val r = group.processIncomingMessage(msg)) {
    is ReceivedMessage.ApplicationMessage ->
        handle(r.data, r.sender)          // sender: SigningIdentity
    is ReceivedMessage.Commit ->
        handleEffect(r.committer, r.effect)
    is ReceivedMessage.ReceivedProposal -> Unit // stored pending
    ReceivedMessage.GroupInfo -> Unit
    ReceivedMessage.Welcome -> Unit
    ReceivedMessage.KeyPackage -> Unit
}
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
let msg = try Message.fromBytes(bytes: wireBytes)   // parse transport bytes
switch try group.processIncomingMessage(message: msg) {
case .applicationMessage(let sender, let data): handle(data, sender)
case .commit(let committer, let effect):        handleEffect(effect)
case .receivedProposal(let sender, let p):      break // pending
case .groupInfo, .welcome, .keyPackage:         break
}
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const r = group.processIncomingMessage(bytes);
// r.kind: "application" | "commit" | "proposal" | "groupInfo" |
//         "welcome" | "keyPackage"
if (r.kind === "application") {
    handle(r.data, r.sender_index);      // Uint8Array, leaf index
}
```

{{#endtab }}
{{#endtabs }}

## Behavior details

* **Validation first** — signatures, membership, epoch, reuse guards
  are all checked before anything is applied. Failures raise `Error` /
  throw.
* **Commits mutate state** — after processing, the group is at the new
  epoch; follow with `writeToStorage()`.
* **Proposals are stored** — they wait for a future commit (see
  [Commits & epochs](commits.md)).
* **Processing your own commit** is safe and expected in the
  committer-applies-then-fans-out pattern.
