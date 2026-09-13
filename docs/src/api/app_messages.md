# Application messages

`encrypt_application_message` seals your payload under the current
epoch's key. The encoding inside is **yours** — MLS sees only bytes.

## `Group::encrypt_application_message`

| Platform | Signature | Returns |
|----------|-----------|---------|
| Rust | `group.encrypt_application_message(data, aad)` | `MlsMessage` |
| Kotlin | `group.encryptApplicationMessage(message: ByteArray)` | `Message` |
| Swift | `group.encryptApplicationMessage(message: Data) throws` | `Message` |
| WASM | `group.encryptApplicationMessage(message: Uint8Array)` | `Uint8Array` |

{{#tabs }}
{{#tab name="Rust" }}

```rust
let ct = group
    .encrypt_application_message(b"hello".as_ref(), vec![] /* aad */)
    .await?;
let bytes = ct.to_bytes()?;
```

{{#endtab }}
{{#tab name="Kotlin" }}

```kotlin
val ct = group.encryptApplicationMessage("hello".toByteArray())
sendToMembers(ct.toBytes())   // wire bytes — the receiver calls
                            // Message.fromBytes(...) then processes
```

{{#endtab }}
{{#tab name="Swift" }}

```swift
let ct = try group.encryptApplicationMessage(message: Data("hello".utf8))
sendToMembers(try ct.toBytes())   // wire bytes
```

{{#endtab }}
{{#tab name="Web (WASM)" }}

```js
const ct = group.encryptApplicationMessage(
    new TextEncoder().encode("hello"));
sendToMembers(ct);   // Uint8Array
```

{{#endtab }}
{{#endtabs }}

## Guarantees

* Confidentiality + integrity under the current epoch secrets.
* **Sender authenticity** — receivers learn the sender's
  `SigningIdentity`, not just "some member".
* **Forward secrecy** — keys ratchet per message (secret tree); a
  leaked epoch state doesn't expose earlier traffic.
* No ordering/dedup by MLS itself — add sequence numbers inside your
  payload if your transport can reorder.

## Receiving

Decryption happens in `processIncomingMessage` →
`ReceivedMessage.ApplicationMessage{sender, data}` — see
[Processing incoming messages](process_incoming.md).
