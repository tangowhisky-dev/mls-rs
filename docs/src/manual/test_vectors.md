# Test vectors & conformance

mls-rs is validated against the official RFC 9420 test vectors plus a
large in-tree test suite. This page shows where they live and how to
run them.

## What is covered

| Suite | Location | Contents |
|-------|----------|----------|
| `mls-rs` core tests | `mls-rs/src/**/tests` | 430+ unit tests: tree math, key schedule, framing, commits, interop vectors |
| Interop test vectors | `mls-rs/test_data/` | pre-computed RFC 9420 vectors (crypto basics, secret tree, tree-kem, key schedule, message protection, passive-client scenarios) |
| Crypto-provider conformance | `mls-rs-crypto-*/` | per-provider `mls_core_tests` — the same MLS core suite runs against RustCrypto, OpenSSL, AWS-LC |
| X.509 | `mls-rs-crypto-*/test_data/x509/` + `platform_testbeds/test_pki/` | CA hierarchies + leaf certs for Ed25519, P-256, P-384, P-521 |
| FFI e2e | `platform_testbeds/` | the cross-platform harnesses described in this book |

## Running the vectors

```sh
# Everything (default workspace members)
cargo test

# Just the RustCrypto provider, incl. the MLS core test suite
cargo test -p mls-rs-crypto-rustcrypto

# The FFI-facing API surface end-to-end
cargo run --release --manifest-path platform_testbeds/rust-harness/Cargo.toml

# Every platform at once
platform_testbeds/scripts/run_all.sh
```

`mls_core_tests` inside each crypto-provider crate runs the shared
conformance suite — key generation, HPKE, signatures, AEAD, KDF — for
every cipher suite that provider supports. For RustCrypto that means
all five suites (1, 2, 3, 5, 7).

## Generating fresh X.509 test material

```sh
platform_testbeds/scripts/gen_test_pki.sh
```

creates per-algorithm CAs + leaf certificates under
`platform_testbeds/test_pki/` (leaf certs signed with the curve-matched
digest the RustCrypto validator expects: P-256→SHA-256, P-384→SHA-384,
P-521→SHA-512, Ed25519→pure). `export_key_json.py` derives the raw
`key.json`/`public.bin`/`secret.bin` files used by the JS/Kotlin/Swift
harnesses.
