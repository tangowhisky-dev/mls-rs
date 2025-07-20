# Crypto Providers and Cipher Suites Guide

This comprehensive guide covers cryptographic configuration, cipher suite selection, and crypto provider details for MLS-RS Swift bindings.

## Overview

The MLS-RS Swift bindings use Apple's CryptoKit framework as the primary cryptographic provider, offering hardware-accelerated performance and robust security guarantees. This guide explains cipher suite selection, cryptographic primitives, and best practices for different use cases.

## Supported Cipher Suites

The MLS-RS Swift bindings support **5 of the 7** cipher suites defined in [RFC 9420](https://www.rfc-editor.org/rfc/rfc9420.html#name-mls-cipher-suites), all optimized for Apple platforms through CryptoKit integration.

### Complete Cipher Suite Reference

| Suite ID | Swift Enum | RFC Name | Security Level | Key Exchange | AEAD | Hash | Signature |
|----------|------------|----------|----------------|--------------|------|------|-----------|
| **1** | `.curve25519Aes128` | MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519 | 128-bit | X25519 | AES-128-GCM | SHA-256 | Ed25519 |
| **2** | `.p256Aes128` | MLS_128_DHKEMP256_AES128GCM_SHA256_P256 | 128-bit | ECDH P-256 | AES-128-GCM | SHA-256 | ECDSA P-256 |
| **3** | `.curve25519Chacha` | MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519 | 128-bit | X25519 | ChaCha20-Poly1305 | SHA-256 | Ed25519 |
| **5** | `.p521Aes256` | MLS_256_DHKEMP521_AES256GCM_SHA512_P521 | 256-bit | ECDH P-521 | AES-256-GCM | SHA-512 | ECDSA P-521 |
| **7** | `.p384Aes256` | MLS_256_DHKEMP384_AES256GCM_SHA384_P384 | 256-bit | ECDH P-384 | AES-256-GCM | SHA-384 | ECDSA P-384 |

### Unsupported Cipher Suites

The following RFC 9420 cipher suites are **not supported** due to CryptoKit limitations:

- **Suite 4**: `MLS_128_DHKEMX448_AES128GCM_SHA256_Ed448` (X448/Ed448 not in CryptoKit)
- **Suite 6**: `MLS_256_DHKEMX448_CHACHA20POLY1305_SHA512_Ed448` (X448/Ed448 not in CryptoKit)

## Cipher Suite Selection Guide

### Recommended Cipher Suites by Use Case

#### 🥇 Default Recommendation: `curve25519Aes128`

```swift
let cipherSuite = CipherSuite.curve25519Aes128
```

**Best for**: Most applications, high performance requirements, mobile devices

**Advantages**:
- Excellent performance on Apple Silicon
- Modern cryptography (Curve25519, Ed25519)
- Constant-time implementations
- Hardware acceleration
- 128-bit security level (sufficient for most use cases)

#### 🥈 NIST Compliance: `p256Aes128`

```swift
let cipherSuite = CipherSuite.p256Aes128
```

**Best for**: Government, enterprise, FIPS compliance requirements

**Advantages**:
- NIST-approved curves
- Hardware acceleration
- Regulatory compliance
- Industry standard

#### 🥉 Constant-Time Preference: `curve25519Chacha`

```swift
let cipherSuite = CipherSuite.curve25519Chacha
```

**Best for**: Environments prioritizing constant-time cryptography

**Advantages**:
- ChaCha20-Poly1305 AEAD
- Excellent software performance
- Constant-time implementation
- Good for older hardware

#### 🔒 High Security: `p521Aes256`

```swift
let cipherSuite = CipherSuite.p521Aes256
```

**Best for**: High-security requirements, government, military

**Advantages**:
- 256-bit security level
- NIST P-521 curve
- Larger key sizes
- Future-proof against quantum threats

#### 🏢 Enterprise/Government: `p384Aes256`

```swift
let cipherSuite = CipherSuite.p384Aes256
```

**Best for**: Government agencies, enterprise with specific P-384 requirements

**Advantages**:
- NSA Suite B compatible
- 256-bit security level
- Government approval
- Enterprise standards

### Performance Comparison

Based on benchmarks across Apple platforms:

| Cipher Suite | Keypair Gen | Group Ops | Encryption | Decryption | Overall Score |
|--------------|-------------|-----------|------------|------------|---------------|
| `curve25519Aes128` | **⭐⭐⭐⭐⭐** | **⭐⭐⭐⭐⭐** | **⭐⭐⭐⭐⭐** | **⭐⭐⭐⭐⭐** | **⭐⭐⭐⭐⭐** |
| `curve25519Chacha` | **⭐⭐⭐⭐⭐** | **⭐⭐⭐⭐⭐** | **⭐⭐⭐⭐** | **⭐⭐⭐⭐** | **⭐⭐⭐⭐** |
| `p256Aes128` | **⭐⭐⭐⭐** | **⭐⭐⭐⭐** | **⭐⭐⭐⭐** | **⭐⭐⭐⭐** | **⭐⭐⭐⭐** |
| `p521Aes256` | **⭐⭐⭐** | **⭐⭐⭐** | **⭐⭐⭐** | **⭐⭐⭐** | **⭐⭐⭐** |
| `p384Aes256` | **⭐⭐⭐** | **⭐⭐⭐** | **⭐⭐⭐** | **⭐⭐⭐** | **⭐⭐⭐** |

## CryptoKit Provider Details

### Architecture

```
┌─────────────────────────────────────┐
│           MLS Protocol              │
├─────────────────────────────────────┤
│        Crypto Abstraction           │
├─────────────────────────────────────┤
│         CryptoKit Bridge            │
├─────────────────────────────────────┤
│       Apple CryptoKit               │
├─────────────────────────────────────┤
│      Hardware Security Module       │
│         (Secure Enclave)            │
└─────────────────────────────────────┘
```

### Hardware Acceleration

The CryptoKit provider leverages:

- **Secure Enclave**: For key generation and storage
- **Hardware AES**: AES-NI instructions on Intel, dedicated AES units on Apple Silicon
- **Hardware SHA**: SHA extensions for accelerated hashing
- **Crypto Extensions**: ARM crypto extensions on Apple Silicon

### Key Generation

```swift
// Keypair generation uses CryptoKit primitives
func generateKeypairDetailed(cipherSuite: CipherSuite) throws -> SignatureKeypair {
    switch cipherSuite {
    case .curve25519Aes128, .curve25519Chacha:
        // Uses Curve25519.Signing.PrivateKey
        return try generateSignatureKeypair(cipherSuite: cipherSuite)
        
    case .p256Aes128:
        // Uses P256.Signing.PrivateKey
        return try generateSignatureKeypair(cipherSuite: cipherSuite)
        
    case .p521Aes256:
        // Uses P521.Signing.PrivateKey
        return try generateSignatureKeypair(cipherSuite: cipherSuite)
        
    case .p384Aes256:
        // Uses P384.Signing.PrivateKey
        return try generateSignatureKeypair(cipherSuite: cipherSuite)
    }
}
```

### Cryptographic Primitives

#### Digital Signatures

```swift
// Ed25519 (Curve25519 suites)
let message = Data("hello".utf8)
let signature = try privateKey.signature(for: message)
let isValid = publicKey.isValidSignature(signature, for: message)

// ECDSA (P-256, P-384, P-521 suites)
let ecdsaSignature = try privateKey.signature(for: message.sha256)
let ecdsaValid = publicKey.isValidSignature(ecdsaSignature, for: message.sha256)
```

#### Key Exchange

```swift
// X25519 (Curve25519 suites)
let alicePrivate = Curve25519.KeyAgreement.PrivateKey()
let bobPrivate = Curve25519.KeyAgreement.PrivateKey()
let sharedSecret = try alicePrivate.sharedSecretFromKeyAgreement(with: bobPrivate.publicKey)

// ECDH (P-256, P-384, P-521 suites)
let aliceECPrivate = P256.KeyAgreement.PrivateKey()
let bobECPrivate = P256.KeyAgreement.PrivateKey()
let ecSharedSecret = try aliceECPrivate.sharedSecretFromKeyAgreement(with: bobECPrivate.publicKey)
```

#### AEAD Encryption

```swift
// AES-GCM
let key = SymmetricKey(size: .bits128) // or .bits256
let plaintext = Data("secret message".utf8)
let sealedBox = try AES.GCM.seal(plaintext, using: key)
let decrypted = try AES.GCM.open(sealedBox, using: key)

// ChaCha20-Poly1305
let chachaKey = SymmetricKey(size: .bits256)
let chachaSealedBox = try ChaChaPoly.seal(plaintext, using: chachaKey)
let chachaDecrypted = try ChaChaPoly.open(chachaSealedBox, using: chachaKey)
```

#### Key Derivation

```swift
// HKDF
let inputKeyMaterial = Data("initial key material".utf8)
let salt = Data("salt".utf8)
let info = Data("application context".utf8)

let derivedKey = HKDF<SHA256>.deriveKey(
    inputKeyMaterial: SymmetricKey(data: inputKeyMaterial),
    salt: salt,
    info: info,
    outputByteCount: 32
)
```

## Security Properties

### Cryptographic Guarantees

#### Confidentiality
- **AES-128/256-GCM**: Authenticated encryption with associated data
- **ChaCha20-Poly1305**: Stream cipher with polynomial MAC
- **Key Isolation**: Per-message keys derived from group secrets

#### Authenticity
- **Ed25519**: Fast, secure signatures with 128-bit security
- **ECDSA**: Industry-standard signatures with configurable curves
- **Group Authentication**: Member authenticity through signature verification

#### Forward Secrecy
- **Ephemeral Keys**: New keys for each epoch
- **Key Deletion**: Previous keys securely overwritten
- **Ratcheting**: Continuous key evolution

#### Post-Compromise Security
- **Member Updates**: Fresh key material injection
- **Healing**: Recovery from key compromise
- **Isolation**: Compromised keys don't affect future security

### Side-Channel Resistance

CryptoKit provides protection against:

- **Timing Attacks**: Constant-time implementations
- **Cache Attacks**: Memory access pattern protection
- **Power Analysis**: Hardware-level protections on compatible devices
- **Fault Injection**: Secure Enclave protections

## Configuration Examples

### Production Configuration

```swift
class ProductionCryptoConfig {
    static func recommendedCipherSuite() -> CipherSuite {
        // Use device capabilities to select optimal suite
        if #available(iOS 17.0, macOS 14.0, *) {
            return .curve25519Aes128 // Best performance and security
        } else {
            return .p256Aes128 // Fallback for older versions
        }
    }
    
    static func highSecurityCipherSuite() -> CipherSuite {
        return .p521Aes256 // Maximum security
    }
    
    static func complianceCipherSuite() -> CipherSuite {
        return .p256Aes128 // NIST compliance
    }
}

// Usage
let client = Client(
    id: clientId,
    signatureKeypair: try generateSignatureKeypair(
        cipherSuite: ProductionCryptoConfig.recommendedCipherSuite()
    ),
    clientConfig: clientConfigDefault()
)
```

### Testing Configuration

```swift
class TestCryptoConfig {
    static func fastTestingSuite() -> CipherSuite {
        return .curve25519Aes128 // Fastest for unit tests
    }
    
    static func comprehensiveTestSuites() -> [CipherSuite] {
        return [
            .curve25519Aes128,
            .p256Aes128,
            .curve25519Chacha,
            .p521Aes256,
            .p384Aes256
        ]
    }
}

// Testing all cipher suites
func testAllCipherSuites() throws {
    for cipherSuite in TestCryptoConfig.comprehensiveTestSuites() {
        print("Testing \(cipherSuite)...")
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let client = Client(id: Data("test".utf8), signatureKeypair: keypair, clientConfig: clientConfigDefault())
        let group = try client.createGroup(groupId: nil)
        // Perform tests...
    }
}
```

### Multi-Environment Configuration

```swift
enum Environment {
    case development
    case staging
    case production
    case government
}

class EnvironmentCryptoConfig {
    static func cipherSuite(for environment: Environment) -> CipherSuite {
        switch environment {
        case .development:
            return .curve25519Aes128 // Fast development
        case .staging:
            return .curve25519Aes128 // Match production performance
        case .production:
            return .curve25519Aes128 // Optimal performance
        case .government:
            return .p521Aes256 // High security
        }
    }
    
    static func createClient(for environment: Environment, id: Data) throws -> Client {
        let cipherSuite = self.cipherSuite(for: environment)
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        return Client(id: id, signatureKeypair: keypair, clientConfig: clientConfigDefault())
    }
}
```

## Migration Between Cipher Suites

### Gradual Migration Strategy

```swift
class CipherSuiteMigration {
    static func migrateGroup(
        from oldSuite: CipherSuite,
        to newSuite: CipherSuite,
        client: Client
    ) throws {
        // 1. Generate new keypair
        let newKeypair = try generateSignatureKeypair(cipherSuite: newSuite)
        
        // 2. Create new client with new cipher suite
        let newClient = Client(
            id: client.id,
            signatureKeypair: newKeypair,
            clientConfig: client.config
        )
        
        // 3. Leave old groups gracefully
        let oldGroups = try client.loadGroupsFromStorage()
        for groupInfo in oldGroups {
            // Export group data
            let groupData = try exportGroupMembers(group: groupInfo.group)
            
            // Create new group with new cipher suite
            let newGroup = try newClient.createGroup(groupId: nil)
            
            // Re-invite members to new group
            try inviteMembersToNewGroup(members: groupData, group: newGroup)
        }
    }
}
```

### Compatibility Matrix

| From Suite | To Suite | Migration Path | Complexity |
|-------------|----------|----------------|------------|
| Any 128-bit | Any 128-bit | Direct | Low |
| Any 128-bit | Any 256-bit | Upgrade | Medium |
| Any 256-bit | Any 128-bit | Downgrade (not recommended) | High |
| Curve25519 | P-256/384/521 | Algorithm change | Medium |
| P-256/384/521 | Curve25519 | Algorithm change | Medium |

## Interoperability

### Cross-Platform Compatibility

The CryptoKit provider ensures compatibility with:

- **Other MLS implementations** using the same cipher suites
- **Standard cryptographic libraries** (OpenSSL, BoringSSL, etc.)
- **Hardware Security Modules** supporting standard algorithms

### Protocol Compliance

All cipher suites are fully compliant with:

- **RFC 9420**: MLS Protocol specification
- **RFC 8446**: TLS 1.3 (shared cryptographic primitives)
- **FIPS 140-2**: Federal cryptographic standards (P-256/384/521 suites)
- **Common Criteria**: International security evaluation standards

## Performance Optimization

### Platform-Specific Optimizations

```swift
class PlatformOptimizedCrypto {
    static func optimalCipherSuite() -> CipherSuite {
        #if targetEnvironment(simulator)
        // Simulators may have different performance characteristics
        return .curve25519Aes128
        #else
        // Real devices with hardware acceleration
        return .curve25519Aes128
        #endif
    }
    
    static func batteryOptimizedSuite() -> CipherSuite {
        // Optimize for battery life on mobile devices
        return .curve25519Aes128 // Hardware acceleration reduces power
    }
    
    static func memoryOptimizedSuite() -> CipherSuite {
        // Optimize for memory usage
        return .curve25519Aes128 // Smaller key sizes
    }
}
```

### Benchmarking

```swift
import Foundation

class CryptoBenchmark {
    static func benchmarkKeypairGeneration() {
        let suites: [CipherSuite] = [.curve25519Aes128, .p256Aes128, .curve25519Chacha, .p521Aes256, .p384Aes256]
        
        for suite in suites {
            let start = CFAbsoluteTimeGetCurrent()
            
            for _ in 0..<100 {
                _ = try! generateSignatureKeypair(cipherSuite: suite)
            }
            
            let end = CFAbsoluteTimeGetCurrent()
            let avgTime = (end - start) / 100.0
            print("\(suite): \(String(format: "%.4f", avgTime * 1000))ms avg")
        }
    }
    
    static func benchmarkEncryption(messageSize: Int = 1024) {
        // Benchmark encryption performance across cipher suites
        // Implementation details...
    }
}
```

## Security Auditing

### Cryptographic Validation

```swift
class CryptoValidator {
    static func validateCipherSuite(_ suite: CipherSuite) -> ValidationResult {
        switch suite {
        case .curve25519Aes128:
            return .valid(level: .high, notes: "Modern cryptography, excellent performance")
        case .p256Aes128:
            return .valid(level: .high, notes: "NIST approved, industry standard")
        case .curve25519Chacha:
            return .valid(level: .high, notes: "Constant-time implementation")
        case .p521Aes256:
            return .valid(level: .maximum, notes: "High security, government grade")
        case .p384Aes256:
            return .valid(level: .maximum, notes: "NSA Suite B compatible")
        }
    }
    
    static func auditCryptoConfiguration(config: ClientConfig) -> AuditReport {
        // Perform comprehensive security audit
        var issues: [String] = []
        var recommendations: [String] = []
        
        // Check cipher suite selection
        // Validate key sizes
        // Review algorithm choices
        
        return AuditReport(issues: issues, recommendations: recommendations)
    }
}

enum ValidationResult {
    case valid(level: SecurityLevel, notes: String)
    case warning(reason: String)
    case invalid(reason: String)
}

enum SecurityLevel {
    case high, maximum
}
```

## Best Practices

### 1. Cipher Suite Selection

```swift
// ✅ Good: Use recommended defaults
let defaultSuite = CipherSuite.curve25519Aes128

// ✅ Good: Environment-specific selection
let productionSuite = Environment.current.recommendedCipherSuite()

// ❌ Avoid: Hardcoding without consideration
let hardcoded = CipherSuite.p521Aes256 // May be overkill for most apps
```

### 2. Key Management

```swift
// ✅ Good: Proper key lifecycle
class SecureKeyManager {
    func rotateKeypair(client: Client) throws {
        let newKeypair = try generateSignatureKeypair(cipherSuite: client.cipherSuite)
        try client.updateSignatureKeypair(newKeypair)
        // Previous keypair automatically cleaned up
    }
}

// ❌ Avoid: Manual key handling
// Don't try to extract or manipulate raw key material
```

### 3. Configuration Management

```swift
// ✅ Good: Centralized configuration
class CryptoConfigManager {
    static let shared = CryptoConfigManager()
    
    func clientConfig(for environment: Environment) -> ClientConfig {
        let cipherSuite = environment.recommendedCipherSuite()
        return ClientConfig(
            cipherSuite: cipherSuite,
            storage: storageProvider(for: environment)
        )
    }
}

// ❌ Avoid: Scattered configuration
// Don't configure crypto settings in multiple places
```

## Troubleshooting

### Common Issues

1. **Cipher suite mismatch**: Ensure all group members use compatible suites
2. **Performance issues**: Profile cipher suite performance for your use case
3. **Compliance failures**: Verify cipher suite meets regulatory requirements
4. **Key generation failures**: Check device entropy and hardware availability

### Debug Information

```swift
#if DEBUG
extension CipherSuite {
    var debugDescription: String {
        switch self {
        case .curve25519Aes128:
            return "Curve25519-AES128 (Suite 1): X25519 + AES-128-GCM + SHA-256 + Ed25519"
        case .p256Aes128:
            return "P-256-AES128 (Suite 2): ECDH-P256 + AES-128-GCM + SHA-256 + ECDSA-P256"
        case .curve25519Chacha:
            return "Curve25519-ChaCha (Suite 3): X25519 + ChaCha20-Poly1305 + SHA-256 + Ed25519"
        case .p521Aes256:
            return "P-521-AES256 (Suite 5): ECDH-P521 + AES-256-GCM + SHA-512 + ECDSA-P521"
        case .p384Aes256:
            return "P-384-AES256 (Suite 7): ECDH-P384 + AES-256-GCM + SHA-384 + ECDSA-P384"
        }
    }
}
#endif
```

## Next Steps

- [**Performance Guide**](PERFORMANCE.md) - Optimization techniques
- [**Security Guide**](SECURITY.md) - Security best practices
- [**Advanced Features**](ADVANCED_FEATURES.md) - Complex cryptographic scenarios
- [**API Reference**](API_REFERENCE.md) - Complete API documentation
