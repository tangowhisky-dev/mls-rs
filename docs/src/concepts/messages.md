# Messages & the delivery service

Everything that moves between clients in MLS is a **message**
(`MlsMessage`). mls-rs treats them as opaque bytes: it produces them,
you transport them, it consumes them.

## The four flows

| Message | Produced by | Consumed by | Audience |
|---------|-------------|-------------|----------|
| KeyPackage | `generateKeyPackageMessage()` | `addMembers` / `proposeAddMembers` | published to your directory server |
| Commit | `commit()`, `addMembers()`, `removeMembers()` | `processIncomingMessage()` | all current members |
| Welcome | inside `CommitOutput` | `joinGroup()` | the newly added members only |
| Application ciphertext | `encryptApplicationMessage()` | `processIncomingMessage()` | all members |

## Your delivery service's responsibilities

```text
┌────────┐  keypackage   ┌─────────────┐  lookup/add   ┌────────┐
│  Bob   │──────────────▶│  Directory/ │◀──────────────│ Alice  │
│        │               │  Delivery   │               │        │
│        │◀──welcome─────│   service   │◀──commit──────│        │
│        │               │             │───commit─────▶│ Carol  │
│        │◀───────ciphertext (fan out)────────────────│        │
└────────┘               └─────────────┘               └────────┘
```

* **Publish key packages** so other clients can fetch them. They expire
  — regenerate periodically.
* **Fan out commits** to *all* existing members *except* the committer
  (the committer already applied it locally; processing your own commit
  is still safe — the testbeds do exactly that).
* **Deliver welcomes** only to the new members (welcome bytes are
  encrypted to them).
* **Relay ciphertexts** to everyone but the sender.
* **Ordering matters** — commits must be delivered in epoch order per
  group. MLS rejects out-of-order epochs.

## Message bytes — the wire boundary

The network boundary is always **raw MLS wire bytes**
(`Vec<u8>`/`ByteArray`/`Data`/`Uint8Array`). Every platform serializes
and parses the same TLS presentation format, so a message produced by
Kotlin can be consumed by Rust, Swift or WASM unchanged:

| Direction | Rust | Kotlin | Swift | WASM |
|-----------|------|--------|-------|------|
| serialize | `msg.to_bytes()` | `msg.toBytes()` | `msg.toBytes()` | already `Uint8Array` |
| parse | `MlsMessage::from_bytes(b)` | `Message.fromBytes(b)` | `Message.fromBytes(bytes: b)` | pass `Uint8Array` directly |
| ratchet tree | `ExportedTree::to_bytes()` / `from_bytes` | `RatchetTree(bytes)` ↔ `.bytes` | `RatchetTree(bytes:)` ↔ `.bytes` | raw `Uint8Array` |

`KeyPackage`, `Welcome`, `Commit`, `GroupInfo`, proposals and
application ciphertexts are all `Message`/`MlsMessage` at the wire
level — one codec covers them all.

> Transport bytes opaquely. Never stringify them; if your channel is
> text-only, wrap in Base64 at the application layer — the byte
> content is identical on every platform.

`scripts/test_interop.sh` exercises exactly this: Kotlin, Swift and
WASM key packages are consumed by Rust to build a welcome, which each
binding then joins and decrypts.
