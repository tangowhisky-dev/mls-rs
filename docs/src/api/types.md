# Data types reference

The shared vocabulary every binding passes around. Field names below
are the UniFFI (Kotlin/Swift) spellings; WASM uses snake_case on plain
objects and Rust uses its own types — noted where they differ.

## Keys & identity

| Type | Fields | Notes |
|------|--------|-------|
| `SignaturePublicKey` | `bytes` | encoded per suite — see [encodings](../concepts/credentials.md#raw-key-encodings) |
| `SignatureSecretKey` | `bytes` | private — never leaves the device |
| `SignatureKeypair` | `cipherSuite`, `publicKey`, `secretKey` | construct to import; or via `generateSignatureKeypair` |
| `SigningIdentity` | (object) | credential + public key; `identifier()` resolves to the app-level id; construct via `newBasic(id, publicKey)`/`newX509(chain, publicKey)`; used by `removeMembers`, returned by `members()`, `memberWithIdentity()`, `sender` on received messages |

## Group I/O

| Type | Fields | Notes |
|------|--------|-------|
| `Message` | (object) | a serialized `MlsMessage`; `toBytes()`/`Message.fromBytes(b)` are the wire boundary — see [interoperability](../concepts/interoperability.md); WASM uses raw `Uint8Array` |
| `RatchetTree` | `bytes` | serialized `ExportedTree` |
| `CommitOutput` | `commitMessage`, `welcomeMessage?`, `ratchetTree?`, `groupInfo?` | see [Adding members](add_members.md); WASM: `commit_message`, `welcome_message`, `ratchet_tree` |
| `JoinInfo` | `group`, `groupInfoExtensions` | result of `joinGroup`; WASM returns just the group |
| `Proposal` | (opaque object) | pending proposal — surfaced via `ReceivedMessage.ReceivedProposal` |
| `Extension` / `ExtensionList` | (opaque objects) | custom extension plumbing; `groupInfoExtensions` on `JoinInfo` |

## Enums

| Enum | Variants |
|------|----------|
| `CipherSuite` | `Curve25519Aes128`(1), `P256Aes128`(2), `Curve25519ChaCha`(3), `P521Aes256`(5), `P384Aes256`(7) |
| `ProtocolVersion` | `Mls10` |
| `ReceivedMessage` | `ApplicationMessage{sender,data}` · `Commit{committer,effect}` · `ReceivedProposal{sender,proposal}` · `GroupInfo` · `Welcome` · `KeyPackage` |
| `CommitEffect` | `NewEpoch{appliedProposals,unusedProposals}` · `ReInit` · `Removed` |
| `Error` | `MlsError` · `AnyError` · `MlsCodecError` · `UnexpectedCallbackError` (flat error strings over FFI) |

WASM collapses `ReceivedMessage` into `WasmReceivedMessage{kind, data?,
sender_index?}` where `kind` is `"application" | "commit" | "proposal" |
"groupInfo" | "welcome" | "keyPackage"`.

## Configuration

| Type | Fields |
|------|--------|
| `ClientConfig` | `groupStateStorage`, `useRatchetTreeExtension`, `rootCaCertificates`, `allowSelfSignedCertificates` — see [Client configuration](../concepts/client_config.md) |
| `EpochRecord` | `id: u64`, `data` — epoch secret blob for `GroupStateStorage` |
