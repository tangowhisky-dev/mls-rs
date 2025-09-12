# Copilot Instructions for mls-rs

This guide enables AI coding agents to be productive in the mls-rs codebase. It summarizes architecture, workflows, conventions, and integration points specific to this project.

## Architecture Overview
- **mls-rs** implements the IETF Messaging Layer Security (MLS) protocol for end-to-end encrypted group messaging.
- The workspace is a multi-crate Rust monorepo:
  - `mls-rs`: Main protocol logic and client interface.
  - `mls-rs-core`: Core protocol types, crypto provider traits, and test vectors.
  - `mls-rs-codec`, `mls-rs-codec-derive`: Serialization and codec support.
  - `mls-rs-crypto-*`: Pluggable crypto providers (OpenSSL, AWS-LC, RustCrypto, CryptoKit, WebCrypto, etc.).
  - `mls-rs-identity-x509`: X.509 credential support.
  - `mls-rs-provider-sqlite`: SQLite-based storage provider.
  - `mls-rs-uniffi`: Language bindings (Swift, Kotlin) via UniFFI.
- Crypto providers are modular; each implements a trait and can be swapped/configured at runtime.
- WASM builds are supported for browser and cross-platform use.

## Developer Workflows
- **Build:** Use `cargo build --workspace` from the repo root to build all crates.
- **Test:** Run `cargo test --workspace` for all tests. Some crates (e.g., `mls-rs-core`, `mls-rs-crypto-*`) have additional test vectors and interop tests.
- **Benchmarks:** Use `cargo bench` in relevant crates (e.g., `mls-rs/benches`).
- **Language Bindings:**
  - Swift: See `mls-rs-uniffi/swift/xcode-test/README.md` for build/test instructions.
  - Kotlin: See `mls-rs-uniffi/kotlin/tests/README.md` for Gradle/JVM integration.
- **CryptoKit Integration:**
  - The `mls-rs-crypto-cryptokit` crate uses a Swift/C bridge (`cryptokit-bridge`) for Apple CryptoKit support. See its README for FFI details.

## Project Conventions
- All protocol features and extension points are implemented as Rust traits for easy customization.
- Storage, credential validation, and crypto providers are pluggable via trait objects.
- Test data and vectors are stored in `test_data/` directories within relevant crates.
- RFC 9420 compliance is strictly maintained; see comments and links in `mls-rs/README.md`.
- WASM and cross-platform builds use feature flags and conditional compilation.

## Integration Points & Dependencies
- Crypto providers communicate via Rust traits; see `mls-rs-core` for trait definitions.
- External dependencies: OpenSSL, AWS-LC, RustCrypto, Apple CryptoKit (via Swift bridge), SQLite.
- Language bindings use UniFFI for Swift/Kotlin integration; see `mls-rs-uniffi/README.md`.
- Interop and security tests rely on pre-computed vectors and external test suites.

## Key Files & Directories
- `mls-rs/README.md`: Protocol overview and feature list.
- `mls-rs-core/src/`: Core protocol logic and traits.
- `mls-rs-crypto-*/src/`: Crypto provider implementations.
- `mls-rs-uniffi/`: Language bindings and integration guides.
- `test_data/`: Test vectors and interop data.

## Example Patterns
- To add a new crypto provider, implement the required trait in a new crate and register it in `mls-rs-core`.
- To extend credential validation, implement a custom trait and configure via the client interface.
- For WASM builds, use `--features wasm` and ensure all dependencies are WASM-compatible.

---
For unclear or incomplete sections, please provide feedback to improve these instructions.
