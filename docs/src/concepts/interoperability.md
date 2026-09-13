# Cross-platform interoperability

This library is designed so an Android app, an iOS app, a browser tab
and a Rust server can sit in **the same MLS group**. The guarantees and
the rules that make it work are collected here.

## The contract

* **One wire format.** Every message — key package, welcome, commit,
  group info, proposal, application ciphertext — is serialized to the
  same MLS TLS presentation bytes on every platform. There is no
  platform-specific encoding. See
  [message bytes](messages.md#message-bytes--the-wire-boundary) for the
  per-language convert/parse calls.
* **One crypto backend.** All bindings run the same RustCrypto provider
  code — there is no "Android variant" vs "iOS variant" of the
  cryptography to diverge.
* **Same cipher suite.** A group's suite is fixed at creation and
  embedded in every key package. Clients on different platforms must
  *generate* key packages for the same suite — pick one suite id
  (1, 2, 3, 5 or 7) in your app and use it everywhere. A Kotlin
  `CURVE25519_AES128` client can only join a group running suite 1.
* **Same credential scheme per group.** Basic and X.509 credentials can
  coexist inside mls-rs, but your identity story must be consistent:
  every member's client must be configured to validate the credential
  types the group actually uses (`rootCaCertificates` for X.509
  groups).

## Converting between wrapper types and bytes

UniFFI wraps serialized values in generated types; WASM keeps raw
bytes. To put any value on the wire:

| Value | Kotlin | Swift | WASM | Rust |
|-------|--------|-------|------|------|
| any message → bytes | `msg.toBytes()` | `msg.toBytes()` | *(already bytes)* | `msg.to_bytes()` |
| bytes → message | `Message.fromBytes(b)` | `Message.fromBytes(bytes: b)` | *(use bytes directly)* | `MlsMessage::from_bytes(b)` |
| tree → bytes | `tree.bytes` | `tree.bytes` | *(already bytes)* | `tree.to_bytes()` |
| bytes → tree | `RatchetTree(b)` | `RatchetTree(bytes: b)` | *(use bytes directly)* | `ExportedTree::from_bytes(b)` |
| signature pubkey | `SignaturePublicKey(b)` | `SignaturePublicKey(bytes: b)` | `keypair.public_key` | raw `Vec<u8>` |

## Recommended settings

These defaults exist specifically so nothing platform-specific leaks
onto the wire:

* **`useRatchetTreeExtension` — leave it `true`** (the default). The
  ratchet tree then travels inside the welcome and `joinGroup` needs no
  out-of-band tree, which is what makes `joinGroup(welcome)` work
  identically on all platforms. If you disable it, you must deliver
  `CommitOutput.ratchetTree`/`ratchet_tree` bytes alongside every
  welcome.
* **`allowSelfSignedCertificates` — keep `false` in production.**
* **Commit fan-out**: send `commitMessage` to every member except the
  committer, `welcomeMessage` only to the new members. All platforms
  produce a *single* welcome covering all adds in one commit
  (`with_single_welcome_message`).

## The key-package storage caveat (important)

Joining a group needs the **HPKE init private key** of your key
package, written to the client's key-package storage when
`generateKeyPackageMessage()` ran. Where that storage lives decides
whether a pending welcome survives a restart:

* **WASM `openPersistent*`**: key packages persist in IndexedDB — a
  welcome addressed to a pre-reload key package can still be joined
  (this is tested end-to-end).
* **In-memory clients** (`new WasmClient(...)`, default
  Kotlin/Swift/Rust in-memory stores): a welcome can only be joined by
  the **same client instance** that generated the key package. Publish
  a fresh key package after restart.
* **Kotlin/Swift**: implement a persistent `key_package_repo` in Rust
  (the UniFFI config currently wires in-memory storage); in Rust,
  `mls-rs-provider-sqlite` persists key packages out of the box.

This is a property of MLS itself, not a binding limitation — the test
harness proves the wire side (`test_interop.sh`).

## Sync vs async

The underlying Rust library compiles **either** a synchronous or an
asynchronous API, selected by the `mls_build_async` `--cfg` flag at
build time — they cannot coexist in one artifact (the same symbols
would collide). The generated bindings inherit whichever was compiled:

* **Default artifacts (all packaging scripts) are synchronous** —
  except WASM, which ships both: `pkg/` (sync — MLS calls return
  values; storage writes commit in the background, settle with
  `flushStorage()`) and `pkg-async/` (async — every call is a
  `Promise` with awaited persistence, like Wire's CoreCrypto API).
  Kotlin/Swift methods block the calling thread — call them from
  `Dispatchers.IO` / a `Task`/background queue, never the UI thread.
* **Async artifact**: WASM's `pkg-async/` is already built by
  `build_wasm.sh`/`package_wasm.sh`. For UniFFI, rebuild the crate
  with `RUSTFLAGS="--cfg mls_build_async"` (the Cargo.toml already
  wires `tokio` for that cfg). UniFFI then generates Kotlin `suspend`
  functions / Swift `async` methods with **identical names and wire
  types** — only the calling convention differs.
* **Rust**: pick sync or async the same way in your own crate.

Wire interop is unaffected — sync and async builds produce identical
bytes.

## Remaining per-binding gaps

| Capability | Kotlin/Swift | WASM |
|------------|--------------|------|
| `Message` ↔ bytes | `toBytes()`/`fromBytes()` | n/a (raw bytes) |
| roster | `members()`, `memberWithIdentity()` | `members()` → `{index, identity, publicKey}` |
| remove member | `removeMembers([SigningIdentity])` | `removeMembers([index])` |
| reconstruct identity | `SigningIdentity.newBasic/newX509` | not needed (index-based) |
| custom storage | `GroupStateStorage` trait | built-in IDB (`openPersistent`) |
| external commits, PSK, exporters, custom proposals | — (Rust only) | — |
| `CommitOutput.groupInfo` | ✅ | not exposed |

Everything in the left column works identically on Kotlin and Swift;
the WASM gaps are thin-wrapper limitations — extend
`platform_testbeds/wasm/mls-rs-wasm` if you need them, the underlying
`mls_rs` APIs are there.
