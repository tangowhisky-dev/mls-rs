# MLS-RS Swift Bindings: Supported Cipher Suites

This document confirms which cipher suites are supported by the MLS-RS Swift bindings and provides examples of their usage.

## Overview

Based on the analysis of the MLS-RS Swift bindings source code, the following cipher suites are **CONFIRMED SUPPORTED**:

| Suite ID | Name | Description |
|----------|------|-------------|
| 1 | `curve25519Aes128` | MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519 |
| 2 | `p256Aes128` | MLS_128_DHKEMP256_AES128GCM_SHA256_P256 |
| 3 | `curve25519Chacha` | MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519 |
| 5 | `p521Aes256` | MLS_256_DHKEMP521_AES256GCM_SHA512_P521 |
| 7 | `p384Aes256` | MLS_256_DHKEMP384_AES256GCM_SHA384_P384 |

These cipher suites align with RFC 9420 specifications and are supported by the underlying CryptoKit provider.

## Code Evidence

### Rust UniFFI Source
The Rust source in `mls-rs-uniffi/src/lib.rs` defines the following:

```rust
/// Supported cipher suites.
///
/// This includes all cipher suites supported by the CryptoKit provider,
/// as documented in RFC 9420: https://www.rfc-editor.org/rfc/rfc9420.html#name-mls-cipher-suites
/// [`mls_rs::CipherSuite`].
#[derive(Copy, Clone, Debug, uniffi::Enum)]
pub enum CipherSuite {
    /// MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519 (Suite ID: 1)
    Curve25519Aes128,
    /// MLS_128_DHKEMP256_AES128GCM_SHA256_P256 (Suite ID: 2)
    P256Aes128,
    /// MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519 (Suite ID: 3)
    Curve25519Chacha,
    /// MLS_256_DHKEMP521_AES256GCM_SHA512_P521 (Suite ID: 5)
    P521Aes256,
    /// MLS_256_DHKEMP384_AES256GCM_SHA384_P384 (Suite ID: 7)
    P384Aes256,
}
```

### Generated Swift Bindings
The generated Swift code in `mls_rs_uniffi.swift` includes:

```swift
public enum CipherSuite {
    /**
     * MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519 (Suite ID: 1)
     */
    case curve25519Aes128
    /**
     * MLS_128_DHKEMP256_AES128GCM_SHA256_P256 (Suite ID: 2)
     */
    case p256Aes128
    /**
     * MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519 (Suite ID: 3)
     */
    case curve25519Chacha
    /**
     * MLS_256_DHKEMP521_AES256GCM_SHA512_P521 (Suite ID: 5)
     */
    case p521Aes256
    /**
     * MLS_256_DHKEMP384_AES256GCM_SHA384_P384 (Suite ID: 7)
     */
    case p384Aes256
}
```

## Usage Examples

### Basic Keypair Generation

```swift
import MlsRs

// Generate keypairs for all supported cipher suites
let curve25519Key = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
let p256Key = try generateSignatureKeypair(cipherSuite: .p256Aes128)
let curve25519ChachaKey = try generateSignatureKeypair(cipherSuite: .curve25519Chacha)
let p521Key = try generateSignatureKeypair(cipherSuite: .p521Aes256)
let p384Key = try generateSignatureKeypair(cipherSuite: .p384Aes256)
```

### Client Creation with Different Cipher Suites

```swift
let clientConfig = clientConfigDefault()

// Create clients with different cipher suites
let curve25519Keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
let curve25519Client = Client(
    id: "curve25519-client".data(using: .utf8)!, 
    signatureKeypair: curve25519Keypair, 
    clientConfig: clientConfig
)

let p256Keypair = try generateSignatureKeypair(cipherSuite: .p256Aes128)
let p256Client = Client(
    id: "p256-client".data(using: .utf8)!, 
    signatureKeypair: p256Keypair, 
    clientConfig: clientConfig
)

let p521Keypair = try generateSignatureKeypair(cipherSuite: .p521Aes256)
let p521Client = Client(
    id: "p521-client".data(using: .utf8)!, 
    signatureKeypair: p521Keypair, 
    clientConfig: clientConfig
)
```

### Complete MLS Workflow with Different Cipher Suites

```swift
func demonstrateCipherSuite(_ cipherSuite: CipherSuite, name: String) throws {
    print("Testing \(name)...")
    
    // Generate keypairs
    let aliceKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
    let bobKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
    
    // Create clients
    let clientConfig = clientConfigDefault()
    var alice = Client(
        id: "alice-\(name)".data(using: .utf8)!,
        signatureKeypair: aliceKeypair,
        clientConfig: clientConfig
    )
    var bob = Client(
        id: "bob-\(name)".data(using: .utf8)!,
        signatureKeypair: bobKeypair,
        clientConfig: clientConfig
    )
    
    // Alice creates a group
    alice = try alice.createGroup(groupId: nil)
    
    // Bob generates a key package
    let bobKeyPackage = try bob.generateKeyPackageMessage()
    
    // Alice adds Bob to the group
    let commit = try alice.addMembers(keyPackages: [bobKeyPackage])
    try alice.processIncomingMessage(message: commit.commitMessage)
    
    // Bob joins the group
    let joinResult = try bob.joinGroup(ratchetTree: nil, welcomeMessage: commit.welcomeMessage)
    bob = joinResult.group
    
    // Test message encryption/decryption
    let message = "Hello from \(name)!"
    let encryptedMessage = try alice.encryptApplicationMessage(message: message.data(using: .utf8)!)
    let decryptedOutput = try bob.processIncomingMessage(message: encryptedMessage)
    let decryptedMessage = String(data: decryptedOutput.data, encoding: .utf8)!
    
    guard decryptedMessage == message else {
        throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Message mismatch"])
    }
    
    print("✅ \(name) cipher suite test passed")
}

// Test all cipher suites
try demonstrateCipherSuite(.curve25519Aes128, name: "Curve25519-AES128")
try demonstrateCipherSuite(.p256Aes128, name: "P-256-AES128")
try demonstrateCipherSuite(.curve25519Chacha, name: "Curve25519-ChaCha20")
try demonstrateCipherSuite(.p521Aes256, name: "P-521-AES256")
try demonstrateCipherSuite(.p384Aes256, name: "P-384-AES256")
```

## Cipher Suite Characteristics

### Suite 1: Curve25519 + AES-128
- **Key Exchange**: X25519 (Curve25519)
- **AEAD**: AES-128-GCM
- **Hash**: SHA-256
- **Signature**: Ed25519
- **Security Level**: 128-bit
- **Use Case**: High performance, widely supported

### Suite 2: P-256 + AES-128
- **Key Exchange**: ECDH over P-256
- **AEAD**: AES-128-GCM
- **Hash**: SHA-256
- **Signature**: ECDSA over P-256
- **Security Level**: 128-bit
- **Use Case**: NIST standard compliance

### Suite 3: Curve25519 + ChaCha20-Poly1305
- **Key Exchange**: X25519 (Curve25519)
- **AEAD**: ChaCha20-Poly1305
- **Hash**: SHA-256
- **Signature**: Ed25519
- **Security Level**: 128-bit
- **Use Case**: Alternative to AES, good for constrained environments

### Suite 5: P-521 + AES-256
- **Key Exchange**: ECDH over P-521
- **AEAD**: AES-256-GCM
- **Hash**: SHA-512
- **Signature**: ECDSA over P-521
- **Security Level**: 256-bit
- **Use Case**: High security requirements

### Suite 7: P-384 + AES-256
- **Key Exchange**: ECDH over P-384
- **AEAD**: AES-256-GCM
- **Hash**: SHA-384
- **Signature**: ECDSA over P-384
- **Security Level**: 192-bit (conservative 256-bit)
- **Use Case**: Government/defense applications

## RFC 9420 Compliance

All supported cipher suites are defined in [RFC 9420 Section 17.1](https://www.rfc-editor.org/rfc/rfc9420.html#name-mls-cipher-suites). The MLS-RS Swift bindings support the cipher suites that are compatible with Apple's CryptoKit framework.

Note that Suite ID 4 (Curve448 + AES-256) and Suite ID 6 (Curve448 + ChaCha20-Poly1305) are not supported as they require Curve448, which is not available in CryptoKit.

## Updated Documentation Needed

The original documentation stating "Currently supports .curve25519Aes128" should be updated to reflect the full list of 5 supported cipher suites:

**Before:**
> Cipher Suite: Currently supports .curve25519Aes128 (Curve25519 for signatures, AES-128-GCM for encryption)

**After:**
> Cipher Suites: Supports 5 cipher suites as defined in RFC 9420:
> - .curve25519Aes128 (Suite 1)
> - .p256Aes128 (Suite 2) 
> - .curve25519Chacha (Suite 3)
> - .p521Aes256 (Suite 5)
> - .p384Aes256 (Suite 7)

## Conclusion

The MLS-RS Swift bindings provide comprehensive support for 5 of the 7 standard MLS cipher suites defined in RFC 9420, covering both 128-bit and 256-bit security levels with multiple cryptographic algorithm choices. This gives developers flexibility to choose appropriate security levels and algorithms based on their specific requirements.
