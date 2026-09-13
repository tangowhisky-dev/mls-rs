# Prerequisites

What you need before integrating, per platform.

## All platforms

| Tool | Why | Install |
|------|-----|---------|
| Rust ≥ 1.85 + cargo | builds `mls-rs-uniffi` / `mls-rs-wasm` | <https://rustup.rs> |
| git checkout of this repo | the source of truth | — |

Rust **targets** — install only the ones you need:

```sh
rustup target add \
    wasm32-unknown-unknown \                    # web / Node
    aarch64-apple-ios aarch64-apple-ios-sim \   # iOS device + simulator
    aarch64-linux-android armv7-linux-androideabi \
    x86_64-linux-android i686-linux-android     # Android ABIs
```

## Rust apps

Nothing extra — the crates are plain dependencies.

## Kotlin / Java

| Tool | Why |
|------|-----|
| `uniffi-bindgen` (in-repo crate) | generates `mls_rs_uniffi.kt` — always version-matched to `uniffi 0.31` |
| `cargo-ndk` | `cargo install cargo-ndk` — cross-links Android `.so`s |
| Android SDK + NDK | `ANDROID_HOME`/`ANDROID_NDK_HOME` env vars; NDK ≥ r25 recommended |
| JNA `net.java.dev.jna:jna` | runtime dependency of the generated bindings (AAR on Android, JAR on JVM) |
| `kotlinc` / Gradle | your app's normal build chain |

## Swift (iOS / macOS)

| Tool | Why |
|------|-----|
| Xcode (with `xcodebuild`) | builds the XCFramework, runs XCTest |
| iOS simulator | for `xcodebuild test` validation |
| Same `uniffi-bindgen` | generates `mls_rs_uniffi.swift` + FFI header/module map |

## WebAssembly

| Tool | Why |
|------|-----|
| `wasm-bindgen-cli` | `cargo install wasm-bindgen-cli` — generates the JS glue |
| Node.js ≥ 18 | runs the e2e test harness |
| Any modern browser | `getrandom/js` pulls CSPRNG from `globalThis.crypto` (secure context or Node) |

## Checking your environment

```sh
platform_testbeds/scripts/env_check.sh
```

prints `[ok]` / `[MISSING]` / `[skip]` for every tool above and exits
non-zero if a *required* tool is absent.
