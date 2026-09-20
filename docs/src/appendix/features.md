# Feature flags

## `mls-rs-uniffi` (Kotlin/Swift bindings)

| Feature | Default | Effect |
|---------|---------|--------|
| `rustcrypto` | ✅ | pure-Rust provider — all platforms, all five suites, X.509 |
| `openssl` | — | OpenSSL provider (where available). **If both are enabled, `rustcrypto` wins.** |

```toml
# Cargo.toml when building the library yourself
mls-rs-uniffi = { path = "...", default-features = false, features = ["openssl"] }
```

## `mls-rs-crypto-rustcrypto`

| Feature | Effect |
|---------|--------|
| `x509` | X.509 certificate parsing/validation via `x509-cert` |
| `browser` | `getrandom/js` — **required** for `wasm32` in browsers/Node |
| `std` | error trait integration, `IntoAnyError` |

## `mls-rs`

| Feature | Effect |
|---------|--------|
| `x509` | X.509 credential types |
| `external_client` | `ExternalClient` / external-commit joins — enabled by `mls-rs-uniffi` and `mls-rs-wasm` |
| `by_ref_credential_proposal` | reference-style credentials in proposals |
| `rayon` (default) | parallel tree ops — **must be off** for `wasm32` (`default-features = false`) |
| `std`, `rfc_compliant`, `tree_index`, `fast_serialize` | the set used by the wasm crate — see `platform_testbeds/wasm/mls-rs-wasm/Cargo.toml` |

## `mls-rs` (async UniFFI builds)

`mls_build_async` cfg switches `mls-rs-uniffi` between sync and async
FFI surfaces. The testbeds use the **sync** build; async requires the
`tokio` runtime wiring upstream provides.
