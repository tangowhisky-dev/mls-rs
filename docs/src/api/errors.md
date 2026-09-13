# Error handling

## How errors surface

{{#tabs }}
{{#tab name="Rust" }}

`Result<T, MlsError>` (rich enum: `UnsupportedCipherSuite`,
`SignatureKeyMismatch` via `AnyError` chains, framing/validation
variants…). Pattern-match or `?`.

{{#endtab }}
{{#tab name="Kotlin" }}

Everything throws `uniffi.mls_rs_uniffi.Error` / `MlsRsUniffiException`
— a *flat* error: variants collapse to a message string
(`MlsError`, `AnyError`, `MlsCodecError`, `UnexpectedCallbackError`).
Catch and inspect `e.message`.

{{#endtab }}
{{#tab name="Swift" }}

Thrown as `MlsRsUniffiError` (`Error` enum, `LocalizedError`). Same flat
semantics — switch on the case or read the message.

{{#endtab }}
{{#tab name="Web (WASM)" }}

Thrown as `JsError`/`Error` with a message string — `try/catch` and
inspect `e.message`.

{{#endtab }}
{{#endtabs }}

## Common error conditions

| Condition | Raised as |
|-----------|-----------|
| Unsupported suite for the backend | `UnsupportedCipherSuite` |
| X.509 chain fails validation / unknown root | X.509 validator error (`AnyError`) |
| Leaf cert public key ≠ keypair public key | `SignatureKeyMismatch` (`AnyError`) |
| Non-basic/X509 credential encountered | `UnsupportedCredentialType` |
| Expired key package / malformed message | decode/validation error |
| Epoch gap (out-of-order commit) | epoch/validation error — redeliver in order |
| `loadGroup` for unknown id | storage/`GroupNotFound` style error |
| Callback into your `GroupStateStorage` fails | `UnexpectedCallbackError` or your error wrapped |

## Practical guidance

* **Distinguish transport vs crypto errors.** FFI errors are flat
  strings — if you need programmatic handling, match on stable
  substrings or keep checks client-side (e.g. verify key lengths before
  constructing a `SignatureKeypair`).
* **Never retry commits blindly.** A failed commit may have partially
  applied — process the delivered commit instead of rebuilding.
* `allowSelfSignedCertificates` swallowing chain errors is a debugging
  aid, not a fix — see the warning in
  [Client configuration](../concepts/client_config.md).
