# Credentials & signature keys

Every group member proves its identity with a **credential** bound to a
**signature keypair**. The binding is what makes MLS messages
attributable: commits and messages are signed with the secret key, and
peers verify against the credential.

## The two credential types

### Basic credentials

An opaque byte identifier (`"alice"`, a UUID, a user handle…). The
library performs no validation — *your* application decides whether the
identifier is trustworthy. Use for development, or when your app
authenticates users out of band.

### X.509 credentials

A DER-encoded certificate **chain** (leaf first). The RustCrypto
validator checks:

* each certificate's signature and validity window,
* that issuers are proper CAs (`BasicConstraints CA:true`,
  `keyCertSign` when `KeyUsage` is present, path-length constraints),
* that the chain terminates at a configured **root CA**
  (`ClientConfig.rootCaCertificates`), or is a single self-signed cert
  when `allowSelfSignedCertificates` is set (**testing only**),
* that the leaf's public key **equals the MLS signing public key**.

The member's MLS identity is extracted from the certificate **subject
common name** (`SubjectIdentityExtractor`). Two members presenting the
same leaf produce the same identity — every client needs its own cert.

## Signature keys

A `SignatureKeypair` ties three things together:

| Field | Meaning |
|-------|---------|
| `cipherSuite` | which algorithms this key is for |
| `publicKey` | goes into key packages / the leaf cert's SPKI |
| `secretKey` | never leaves the device; signs every MLS message |

### Raw key encodings

When importing existing keys (e.g. a private key belonging to a
certificate), the secret/public bytes use these encodings:

| Suite | `publicKey` | `secretKey` |
|-------|-------------|-------------|
| 1, 3 (Ed25519) | 32 B | 64 B `secret‖public` keypair |
| 2 (P-256) | 65 B SEC1 uncompressed | 32 B scalar |
| 5 (P-521) | 133 B SEC1 uncompressed | 66 B scalar |
| 7 (P-384) | 97 B SEC1 uncompressed | 48 B scalar |

Wrong-length or mismatched keys surface as
`SignatureKeyMismatch`/crypto errors at client creation.

### Generating vs importing

* **Generate** with `generate_signature_keypair` (all platforms) — see
  [Generating signature keys](../api/signature_keys.md).
* **Import** by constructing a `SignatureKeypair`/`WasmSignatureKeypair`
  directly from raw bytes — required when the key already exists inside
  an X.509 certificate or secure hardware.

### Signing identity

`client.signingIdentity()` returns the `SigningIdentity` (credential +
public key) the client presents. You pass these to
`Group.removeMembers`/`proposeRemoveMembers` — see
[Removing members](../api/remove_members.md).
