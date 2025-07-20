# MLS-RS Swift Bindings - Developer Documentation Index

Welcome to the comprehensive documentation for MLS-RS Swift bindings. This documentation provides everything you need to integrate secure group messaging into your iOS and macOS applications.

## Documentation Overview

This directory contains comprehensive documentation for the MLS-RS Swift bindings:

- **[OVERVIEW.md](OVERVIEW.md)** - Introduction to MLS and architectural overview
- **[BASIC_USAGE.md](BASIC_USAGE.md)** - Getting started guide with step-by-step examples  
- **[STORAGE_USAGE.md](STORAGE_USAGE.md)** - Persistence and SwiftData integration patterns
- **[CRYPTO_PROVIDERS.md](CRYPTO_PROVIDERS.md)** - Security, cipher suites, and crypto provider details
- **[API_REFERENCE.md](API_REFERENCE.md)** - Complete public API documentation for Swift bindings

### 📖 Reference Materials
- [**API Coverage Report**](../API_COVERAGE_REPORT.md) - Complete API documentation
- [**Cipher Suites**](../CIPHER_SUITES.md) - Supported cipher suites reference
- [**Examples**](../../examples/) - Complete working examples

## 🚀 Getting Started

### New to MLS?
Start with the [**Overview**](OVERVIEW.md) to understand MLS concepts and architecture.

### Ready to Code?
Jump to [**Basic Usage**](BASIC_USAGE.md) for a hands-on tutorial.

### Need Specific Information?
Use the topic-specific guides below.

## 📋 Documentation Topics

### 1. Overview & Architecture
**File**: [OVERVIEW.md](OVERVIEW.md)

Learn about:
- MLS protocol fundamentals
- Swift bindings architecture
- Security properties and guarantees
- Platform support and requirements
- Integration patterns

### 2. Basic Usage Tutorial
**File**: [BASIC_USAGE.md](BASIC_USAGE.md)

Step-by-step guide covering:
- Client setup and configuration
- Cipher suite selection
- Group creation and management
- Message encryption/decryption
- Error handling patterns
- Complete working examples

### 3. Storage & Persistence
**File**: [STORAGE_USAGE.md](STORAGE_USAGE.md)

Comprehensive storage guide:
- SwiftData integration (recommended)
- Custom storage providers
- Data lifecycle management
- Performance optimization
- Security considerations
- Migration strategies

### 4. Cryptography & Security
**File**: [CRYPTO_PROVIDERS.md](CRYPTO_PROVIDERS.md)

Deep dive into cryptographic aspects:
- Cipher suite reference (all 5 supported suites)
- CryptoKit provider details
- Security guarantees and properties
- Performance characteristics
- Configuration best practices
- Compliance and auditing

## 🎯 Quick Navigation

### By Experience Level

#### 🟢 Beginner
1. [Overview](OVERVIEW.md) - Start here
2. [Basic Usage](BASIC_USAGE.md) - First steps
3. [Examples](../../examples/ios-basic/) - Working code

#### 🟡 Intermediate
1. [Storage Usage](STORAGE_USAGE.md) - Persistence patterns
2. [Crypto Providers](CRYPTO_PROVIDERS.md) - Security configuration
3. [API Coverage](../API_COVERAGE_REPORT.md) - Complete API reference

#### 🔴 Advanced
1. [Storage Performance](STORAGE_USAGE.md#performance-optimization) - Optimization
2. [Security Auditing](CRYPTO_PROVIDERS.md#security-auditing) - Security review
3. [Custom Providers](STORAGE_USAGE.md#custom-storage-providers) - Extensions

### By Use Case

#### 📱 iOS App Development
- [Basic Usage](BASIC_USAGE.md) - Core integration
- [SwiftData Storage](STORAGE_USAGE.md#swiftdata-integration-deep-dive) - Data persistence
- [iOS Example](../../examples/ios-basic/) - Complete iOS app

#### 🖥️ macOS App Development
- [Overview](OVERVIEW.md#platform-support) - Platform specifics
- [Storage Options](STORAGE_USAGE.md#storage-backends) - macOS storage
- [Performance](CRYPTO_PROVIDERS.md#performance-optimization) - macOS optimization

#### 🔒 Security-Critical Applications
- [Cipher Suite Selection](CRYPTO_PROVIDERS.md#cipher-suite-selection-guide) - Security choice
- [Security Properties](OVERVIEW.md#security-properties) - Guarantees
- [Auditing](CRYPTO_PROVIDERS.md#security-auditing) - Security validation

#### 🏢 Enterprise Integration
- [Compliance](CRYPTO_PROVIDERS.md#interoperability) - Standards compliance
- [Storage Security](STORAGE_USAGE.md#security-considerations) - Enterprise storage
- [Migration](CRYPTO_PROVIDERS.md#migration-between-cipher-suites) - Enterprise migration

## 🔗 External Resources

### MLS Protocol
- [RFC 9420 - MLS Protocol](https://www.rfc-editor.org/rfc/rfc9420.html)
- [MLS Working Group](https://datatracker.ietf.org/wg/mls/about/)

### Apple Frameworks
- [CryptoKit Documentation](https://developer.apple.com/documentation/cryptokit)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)

### Development Tools
- [Swift Package Manager](https://swift.org/package-manager/)
- [Xcode Documentation](https://developer.apple.com/xcode/)

## 📊 Cipher Suite Quick Reference

| Suite | Swift Enum | Security | Performance | Use Case |
|-------|------------|----------|-------------|----------|
| **1** | `.curve25519Aes128` | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | **Recommended default** |
| **2** | `.p256Aes128` | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | NIST compliance |
| **3** | `.curve25519Chacha` | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Constant-time preference |
| **5** | `.p521Aes256` | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | High security |
| **7** | `.p384Aes256` | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Government/enterprise |

## ⚡ Quick Start Code

```swift
import MlsRs

// 1. Generate identity
let keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)

// 2. Create client
let client = Client(
    id: Data("alice".utf8),
    signatureKeypair: keypair,
    clientConfig: clientConfigDefault()
)

// 3. Create group
let group = try client.createGroup(groupId: nil)

// 4. Send secure message
let message = Data("Hello, secure world!".utf8)
let encrypted = try group.encryptApplicationMessage(message: message)
```

## 🧭 Navigation Tips

### Finding Information
- Use **Cmd+F** to search within documents
- Check the **Table of Contents** in each guide
- Look for **code examples** throughout the documentation

### Code Examples
- All examples are **tested and verified**
- Copy-paste friendly formatting
- **Error handling** included where appropriate

### Cross-References
- **Internal links** connect related topics
- **External links** provide additional context
- **API references** link to detailed documentation

## 📝 Documentation Standards

### Code Quality
- ✅ All code examples are tested
- ✅ Error handling patterns included
- ✅ Performance considerations noted
- ✅ Security best practices highlighted

### Coverage
- ✅ Beginner to advanced topics
- ✅ Multiple use cases and scenarios
- ✅ Platform-specific considerations
- ✅ Real-world examples and patterns

### Maintenance
- ✅ Regular updates with library changes
- ✅ Version compatibility notes
- ✅ Deprecated feature migration guides
- ✅ Community feedback incorporation

## 🤝 Contributing

Found an issue or want to improve the documentation?

1. **Report Issues**: Use GitHub issues for bugs or unclear documentation
2. **Suggest Improvements**: Pull requests welcome for documentation enhancements
3. **Share Examples**: Contribute real-world usage examples
4. **Ask Questions**: Join discussions for clarification and improvements

## 📄 License

This documentation is part of the MLS-RS project and follows the same licensing terms.

---

**Happy coding with MLS-RS Swift bindings!** 🎉

Start your journey with the [**Overview**](OVERVIEW.md) or jump straight to [**Basic Usage**](BASIC_USAGE.md) if you're ready to code.
