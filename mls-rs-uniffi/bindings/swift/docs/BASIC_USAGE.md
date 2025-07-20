# Basic Usage Guide

This guide walks you through the fundamental operations of the MLS-RS Swift bindings, from setting up your first client to conducting secure group messaging.

## Prerequisites

- iOS 17.0+ or macOS 14.0+
- Xcode 15.0+
- Swift Package Manager integration completed

## Step 1: Import and Basic Setup

```swift
import MlsRs
import Foundation

// All MLS operations can throw errors, so wrap in do-catch
do {
    // Your MLS code here
} catch let error as MlsError {
    print("MLS Error: \(error.message)")
}
```

## Step 2: Choose a Cipher Suite

Select an appropriate cipher suite for your security requirements:

```swift
// For most applications, curve25519Aes128 provides excellent security and performance
let cipherSuite = CipherSuite.curve25519Aes128

// For higher security requirements
let highSecuritySuite = CipherSuite.p521Aes256

// For environments preferring ChaCha20
let chachaSuite = CipherSuite.curve25519Chacha
```

### Cipher Suite Selection Guidelines

| Cipher Suite | Use Case | Performance | Security Level |
|--------------|----------|-------------|----------------|
| `curve25519Aes128` | **Recommended default** | Excellent | 128-bit |
| `p256Aes128` | NIST compliance required | Good | 128-bit |
| `curve25519Chacha` | Constant-time preference | Excellent | 128-bit |
| `p521Aes256` | High security requirements | Good | 256-bit |
| `p384Aes256` | Government/enterprise | Good | 256-bit |

## Step 3: Generate Client Identity

Every client needs a cryptographic identity:

```swift
// Generate a signature keypair
let aliceKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
let bobKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)

// Create unique client identifiers
let aliceId = Data("alice@example.com".utf8)
let bobId = Data("bob@example.com".utf8)
```

## Step 4: Configure Client Settings

Set up client configuration:

```swift
// Use default configuration for simple cases
let defaultConfig = clientConfigDefault()

// Or customize configuration for specific needs
let customConfig = ClientConfig(
    // Add custom storage, policies, etc.
)
```

## Step 5: Create MLS Clients

```swift
// Create Alice's client
let alice = Client(
    id: aliceId,
    signatureKeypair: aliceKeypair,
    clientConfig: defaultConfig
)

// Create Bob's client
let bob = Client(
    id: bobId,
    signatureKeypair: bobKeypair,
    clientConfig: defaultConfig
)

print("✅ Created clients for Alice and Bob")
```

## Step 6: Create an MLS Group

Alice creates a new group:

```swift
// Create a new group (groupId is auto-generated if nil)
let aliceGroup = try alice.createGroup(groupId: nil)

print("✅ Alice created a new group")
```

## Step 7: Add Members to the Group

Bob needs to generate a key package to join:

```swift
// Bob generates a key package
let bobKeyPackage = try bob.generateKeyPackageMessage()

// Alice adds Bob to the group
let addResult = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])

print("✅ Alice generated commit to add Bob")
```

## Step 8: Process the Commit

Alice processes her own commit:

```swift
// Alice processes her own commit
let aliceProcessResult = try aliceGroup.processIncomingMessage(message: addResult.commitMessage)

print("✅ Alice processed her own commit")
```

## Step 9: Bob Joins the Group

Bob uses the welcome message to join:

```swift
// Extract the welcome message
guard let welcomeMessage = addResult.welcomeMessage else {
    throw MLSError("No welcome message generated")
}

// Bob joins the group
let joinResult = try bob.joinGroup(
    ratchetTree: nil,
    welcomeMessage: welcomeMessage
)
let bobGroup = joinResult.group

print("✅ Bob joined the group")
```

## Step 10: Send and Receive Messages

Now both clients can exchange secure messages:

```swift
// Alice sends a message
let aliceMessage = Data("Hello Bob! This is a secure message.".utf8)
let encryptedFromAlice = try aliceGroup.encryptApplicationMessage(message: aliceMessage)

print("📤 Alice sent encrypted message")

// Bob receives and decrypts the message
let bobProcessResult = try bobGroup.processIncomingMessage(message: encryptedFromAlice)

if case .applicationMessage(let senderId, let decryptedData) = bobProcessResult {
    let decryptedMessage = String(data: decryptedData, encoding: .utf8) ?? ""
    print("📥 Bob received: '\(decryptedMessage)'")
    print("   From sender: \(String(data: senderId, encoding: .utf8) ?? "unknown")")
}
```

### Bidirectional Communication

```swift
// Bob replies
let bobReply = Data("Hi Alice! Received your secure message.".utf8)
let encryptedFromBob = try bobGroup.encryptApplicationMessage(message: bobReply)

// Alice receives Bob's reply
let aliceProcessResult = try aliceGroup.processIncomingMessage(message: encryptedFromBob)

if case .applicationMessage(let senderId, let decryptedData) = aliceProcessResult {
    let decryptedReply = String(data: decryptedData, encoding: .utf8) ?? ""
    print("📥 Alice received reply: '\(decryptedReply)'")
}
```

## Step 11: Persist Group State

Save group state for later use:

```swift
// Save Alice's group state
try aliceGroup.writeToStorage()

// Save Bob's group state  
try bobGroup.writeToStorage()

print("💾 Group states saved to storage")
```

## Complete Example

Here's a complete, runnable example:

```swift
import MlsRs
import Foundation

func basicMLSWorkflow() throws {
    print("🚀 Starting MLS Basic Workflow")
    
    // 1. Choose cipher suite
    let cipherSuite = CipherSuite.curve25519Aes128
    
    // 2. Generate identities
    let aliceKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
    let bobKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
    
    // 3. Create clients
    let alice = Client(
        id: Data("alice".utf8),
        signatureKeypair: aliceKeypair,
        clientConfig: clientConfigDefault()
    )
    
    let bob = Client(
        id: Data("bob".utf8),
        signatureKeypair: bobKeypair,
        clientConfig: clientConfigDefault()
    )
    
    // 4. Alice creates group
    let aliceGroup = try alice.createGroup(groupId: nil)
    
    // 5. Bob generates key package
    let bobKeyPackage = try bob.generateKeyPackageMessage()
    
    // 6. Alice adds Bob
    let addResult = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])
    let _ = try aliceGroup.processIncomingMessage(message: addResult.commitMessage)
    
    // 7. Bob joins
    let bobGroup = try bob.joinGroup(
        ratchetTree: nil,
        welcomeMessage: addResult.welcomeMessage!
    ).group
    
    // 8. Exchange messages
    let message = Data("Hello from Alice!".utf8)
    let encrypted = try aliceGroup.encryptApplicationMessage(message: message)
    
    let result = try bobGroup.processIncomingMessage(message: encrypted)
    if case .applicationMessage(_, let data) = result {
        let received = String(data: data, encoding: .utf8) ?? ""
        print("✅ Bob received: \(received)")
    }
    
    // 9. Save state
    try aliceGroup.writeToStorage()
    try bobGroup.writeToStorage()
    
    print("🎉 Basic workflow completed successfully!")
}

// Run the example
do {
    try basicMLSWorkflow()
} catch {
    print("❌ Error: \(error)")
}
```

## Error Handling Best Practices

### Common Error Types

```swift
do {
    // MLS operations
} catch let error as MlsError {
    // Handle MLS-specific errors
    switch error.message {
    case let msg where msg.contains("group not found"):
        // Handle missing group
        break
    case let msg where msg.contains("invalid signature"):
        // Handle authentication failure
        break
    default:
        // Handle other MLS errors
        print("MLS Error: \(error.message)")
    }
} catch {
    // Handle other Swift errors
    print("General error: \(error)")
}
```

### Validation Patterns

```swift
// Validate inputs before MLS operations
func validateClientId(_ id: Data) throws {
    guard !id.isEmpty else {
        throw ValidationError("Client ID cannot be empty")
    }
    guard id.count <= 255 else {
        throw ValidationError("Client ID too long")
    }
}

// Validate message data
func validateMessage(_ data: Data) throws {
    guard !data.isEmpty else {
        throw ValidationError("Message cannot be empty")
    }
    guard data.count <= 1024 * 1024 else { // 1MB limit
        throw ValidationError("Message too large")
    }
}
```

## Performance Tips

### Efficient Group Operations

```swift
// Batch member additions when possible
let newMemberKeyPackages = [keyPackage1, keyPackage2, keyPackage3]
let batchAddResult = try group.addMembers(keyPackages: newMemberKeyPackages)
```

### Async/Await Support (Future Enhancement)

```swift
// When async support becomes available:
let group = try await client.createGroupAsync(groupId: nil)
let encrypted = try await group.encryptApplicationMessageAsync(message: data)
```

### Memory Management

```swift
// The bindings handle memory management automatically
// No manual cleanup required for MLS objects
// Swift ARC manages object lifecycles
```

## Next Steps

Now that you understand basic MLS operations, explore:

- [**Storage Usage**](STORAGE_USAGE.md) - Persistent storage patterns
- [**Advanced Features**](ADVANCED_FEATURES.md) - Group management, member removal, updates
- [**Crypto Providers**](CRYPTO_PROVIDERS.md) - Cryptographic configuration
- [**Performance Guide**](PERFORMANCE.md) - Optimization techniques

## Troubleshooting

### Common Issues

1. **"commit already pending"**: Don't call multiple operations before processing commits
2. **"group not found"**: Ensure group state is properly loaded from storage
3. **"invalid key package"**: Verify cipher suite compatibility between clients
4. **"authentication failed"**: Check client identity and signature keypair validity

### Debug Logging

```swift
// Enable debug logging in debug builds
#if DEBUG
print("Group state: \(group.debugDescription ?? "unknown")")
#endif
```
