# MLS-RS Swift iOS Bindings

This directory contains Swift bindings for the mls-rs library, providing a native iOS interface for Messaging Layer Security (MLS) functionality.

## Overview

The MLS-RS Swift bindings enable iOS developers to integrate end-to-end encrypted group messaging capabilities into their applications using Apple's preferred programming language. These bindings are generated automatically using UniFFI and packaged as an XCFramework for easy distribution.

```
+-------------------------+
|      iOS Application    |
+------------+------------+
             |
             | Swift
             |
+------------+------------+
|     MLS-RS Bindings     |
+------------+------------+
             |
             | UniFFI
             |
+------------+------------+
|       mls-rs-uniffi     |
+------------+------------+
             |
             | Rust FFI
             |
+------------+------------+
|         mls-rs          |
+-------------------------+
```

## Features

- **Complete MLS Implementation**: Full support for MLS RFC 9420 including group creation, member management, and message encryption/decryption
- **Swift-Native API**: Idiomatic Swift interfaces with proper error handling and async/await support
- **Cross-Platform**: Supports iOS devices, iOS Simulator, and macOS
- **XCFramework Distribution**: Ready-to-use framework bundle for easy integration
- **Async/Await Support**: Modern Swift concurrency patterns (when built with async support)

## Platform Requirements

- **iOS**: 17.0 or later
- **macOS**: 14.0 or later
- **Xcode**: 15.0 or later
- **Swift**: 5.9 or later

*Note: The minimum iOS version requirement is due to HPKE support in CryptoKit.*

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/awslabs/mls-rs", branch: "main")
]
```

Then add "MlsRs" to your target dependencies:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "MlsRs", package: "mls-rs")
    ]
)
```

### Xcode Project

1. In Xcode, go to File → Add Package Dependencies
2. Enter the repository URL: `https://github.com/awslabs/mls-rs`
3. Select the version or branch you want to use
4. Add the "MlsRs" library to your target

## Basic Usage

### Creating Clients

```swift
import MlsRs

// Get default configuration
let config = clientConfigDefault()

// Generate signature keypairs
let aliceKey = generateSignatureKeypair(cipherSuite: .curve25519Aes128)
let bobKey = generateSignatureKeypair(cipherSuite: .curve25519Aes128)

// Create clients
let alice = try Client(
    identity: Data("alice".utf8),
    signingKey: aliceKey,
    config: config
)

let bob = try Client(
    identity: Data("bob".utf8),
    signingKey: bobKey,
    config: config
)
```

### Group Creation and Management

```swift
// Alice creates a new group
alice = try alice.createGroup(externalPsk: nil)

// Bob generates a key package to join
let keyPackage = try bob.generateKeyPackageMessage()

// Alice adds Bob to the group
let commit = try alice.addMembers(keyPackages: [keyPackage])

// Alice processes her own commit
try alice.processIncomingMessage(message: commit.commitMessage)

// Bob joins the group
let joinResult = try bob.joinGroup(
    externalPsk: nil,
    welcomeMessage: commit.welcomeMessage
)
bob = joinResult.group
```

### Message Encryption and Decryption

```swift
// Alice encrypts a message
let plaintext = Data("Hello, Bob!".utf8)
let encryptedMessage = try alice.encryptApplicationMessage(data: plaintext)

// Bob processes the incoming message
let output = try bob.processIncomingMessage(message: encryptedMessage)
let decryptedText = String(data: output.data, encoding: .utf8)
print("Received: \(decryptedText ?? "")") // "Received: Hello, Bob!"
```

### Async/Await Usage

When built with async support, all operations can be performed asynchronously:

```swift
// Async client creation
let alice = try await Client(
    identity: Data("alice".utf8),
    signingKey: aliceKey,
    config: config
)

// Async group operations
alice = try await alice.createGroup(externalPsk: nil)
let commit = try await alice.addMembers(keyPackages: [keyPackage])

// Async message handling
let encryptedMessage = try await alice.encryptApplicationMessage(data: plaintext)
let output = try await bob.processIncomingMessage(message: encryptedMessage)
```

### Storage Management

MLS requires persistent storage to maintain group state across app sessions. The Swift bindings provide a flexible storage system through the `GroupStateStorage` protocol.

```swift
// Custom storage implementation
class MyStorage: GroupStateStorage {
    func state(groupId: Data) throws -> Data? {
        // Return stored group state for the given group ID
        return loadGroupState(groupId)
    }
    
    func epoch(groupId: Data, epochId: UInt64) throws -> Data? {
        // Return specific epoch data
        return loadEpochData(groupId, epochId)
    }
    
    func write(groupId: Data, groupState: Data, 
               epochInserts: [EpochRecord], epochUpdates: [EpochRecord]) throws {
        // Store group state and epoch records
        saveGroupState(groupId, groupState)
        for epoch in epochInserts {
            saveEpochData(groupId, epoch.id, epoch.data)
        }
        for epoch in epochUpdates {
            updateEpochData(groupId, epoch.id, epoch.data)
        }
    }
    
    func maxEpochId(groupId: Data) throws -> UInt64? {
        // Return the highest epoch ID for this group
        return getMaxEpochId(groupId)
    }
}

// Configure client with custom storage
let storage = MyStorage()
let config = ClientConfig(
    groupStateStorage: storage,
    useRatchetTreeExtension: true
)

let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)

// Persist client state
try group.writeToStorage()

// Storage is automatically used for state persistence
// No additional code needed - the MLS library handles storage calls
```

#### Storage Providers

The mls-rs project includes several storage provider implementations:

- **SwiftData Storage** (`SwiftDataStorage`): Modern Apple-native storage using SwiftData framework
- **In-Memory Storage**: For testing and temporary sessions
- **SQLite Storage** (`mls-rs-provider-sqlite`): Production-ready SQL database storage
- **Custom Storage**: Implement `GroupStateStorage` for specific backends

For iOS applications, consider these storage strategies:

- **SwiftData**: Modern Apple framework with seamless SwiftUI integration (iOS 17+/macOS 14+)
- **Core Data**: Implement `GroupStateStorage` using Core Data for complex app integration
- **SQLite**: Direct SQLite usage for performance-critical applications
- **File System**: Simple file-based storage for smaller deployments
- **Keychain**: For sensitive cryptographic state (use with caution)

#### SwiftData Storage Provider

The `SwiftDataStorage` provider offers Apple's most modern data persistence solution:

```swift
import SwiftData

// Initialize SwiftData storage
let storage = try SwiftDataStorage(inMemory: false)

// Or for testing
let testStorage = try SwiftDataStorage(inMemory: true)

// Use with MLS client configuration
let config = ClientConfig(
    groupStateStorage: storage,
    useRatchetTreeExtension: true
)
```

**Features:**
- Automatic schema management with `@Model` classes
- Thread-safe operations with serial queue coordination
- Efficient querying with `#Predicate` and `FetchDescriptor`
- Built-in data migration support
- SwiftUI integration with `@Query` compatibility
- Performance optimization for large datasets

**SwiftUI Integration:**

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [MLSGroupState.self, MLSEpochData.self])
        }
    }
}

struct ContentView: View {
    @Query private var groups: [MLSGroupState]
    
    var body: some View {
        List(groups, id: \.groupId) { group in
            Text("Group: \(group.groupId.prefix(8))...")
                .font(.monospaced())
        }
    }
}
```

**Advanced Usage:**

```swift
// Custom ModelContainer configuration
let schema = Schema([MLSGroupState.self, MLSEpochData.self])
let configuration = ModelConfiguration(
    schema: schema,
    isStoredInMemoryOnly: false,
    allowsSave: true,
    cloudKitDatabase: .private("iCloud.com.yourapp.mls") // iCloud sync
)

let container = try ModelContainer(for: schema, configurations: [configuration])
let storage = SwiftDataStorage(modelContainer: container)

// Maintenance operations
try storage.cleanupOldEpochs(keepLastN: 50)
let stats = try storage.getStorageStats()
print("Groups: \(stats.groupCount), Epochs: \(stats.totalEpochs)")

// Group management
try storage.deleteGroup(groupId: oldGroupId)
let allGroups = try storage.getAllGroupIds()
```

#### Storage Implementation Example

```swift
import SQLite3

class SQLiteStorage: GroupStateStorage {
    private let dbPath: String
    private var db: OpaquePointer?
    
    init(path: String) throws {
        self.dbPath = path
        try openDatabase()
        try createTables()
    }
    
    func state(groupId: Data) throws -> Data? {
        let sql = "SELECT state FROM groups WHERE group_id = ?"
        // Implementation details...
    }
    
    func write(groupId: Data, groupState: Data, 
               epochInserts: [EpochRecord], epochUpdates: [EpochRecord]) throws {
        let sql = "INSERT OR REPLACE INTO groups (group_id, state) VALUES (?, ?)"
        // Implementation details...
    }
    
    // Additional methods...
}
```

## Examples and Testing

The package includes comprehensive examples demonstrating different storage providers and usage patterns:

### Basic Usage Example
```bash
swift run MLSExample
```

### Storage Examples
```bash
# In-memory storage with custom implementation
swift run MLSStorageExample

# SwiftData storage with modern Apple persistence
swift run SwiftDataExample
```

### Running Tests
```bash
# Run all tests
swift test

# Run specific storage tests
swift test --filter SwiftDataStorageTests
swift test --filter MlsRsTests
```

## Storage Provider Comparison

| Provider | Platform Support | Performance | SwiftUI Integration | Production Ready |
|----------|------------------|-------------|---------------------|------------------|
| SwiftData | iOS 17+, macOS 14+ | Excellent | Native | ✅ |
| In-Memory | All | Fastest | Manual | Testing Only |
| SQLite | All | Very Good | Manual | ✅ |
| Core Data | iOS 13+, macOS 10.15+ | Good | Good | ✅ |
| File System | All | Good | Manual | Limited |

Choose based on your app's requirements:
- **SwiftData**: Best for new apps targeting latest iOS/macOS
- **Core Data**: For existing apps with Core Data infrastructure
- **SQLite**: For cross-platform or performance-critical scenarios
- **In-Memory**: For testing and temporary sessions only

### Prerequisites

- Rust toolchain with iOS targets
- Xcode with command line tools
- Swift 5.9 or later

### Install Rust targets

```bash
rustup target add aarch64-apple-ios
rustup target add aarch64-apple-ios-sim
rustup target add x86_64-apple-ios
rustup target add aarch64-apple-darwin
rustup target add x86_64-apple-darwin
```

### Build XCFramework

```bash
cd mls-rs-uniffi/bindings
./build-xcframework.sh release
```

This will:
1. Build the Rust library for all iOS targets
2. Generate Swift bindings using UniFFI
3. Create individual frameworks for each architecture
4. Combine them into a single XCFramework

### Running Tests

```bash
cd mls-rs-uniffi/bindings/swift
swift test
```

## Error Handling

The Swift bindings use Swift's built-in error handling mechanisms:

```swift
do {
    let result = try client.encryptApplicationMessage(data: data)
    // Handle success
} catch let error as MlsError {
    // Handle MLS-specific errors
    print("MLS Error: \(error)")
} catch {
    // Handle other errors
    print("Unexpected error: \(error)")
}
```

## API Reference

The generated Swift bindings closely mirror the Rust API with Swift-appropriate naming conventions:

- **Client**: Main interface for MLS operations
- **CipherSuite**: Supported cryptographic configurations
- **KeyPackage**: Member authentication and encryption keys
- **GroupInfo**: Group metadata and state
- **ApplicationMessage**: Encrypted user messages

For detailed API documentation, see the generated Swift documentation or refer to the [mls-rs documentation](https://docs.rs/mls-rs/).

## Troubleshooting

### Build Issues

**Problem**: "No such module 'MlsRs'"
**Solution**: Ensure the package is properly added to your project and that you're importing the correct module name.

**Problem**: "Unsupported minimum deployment target"
**Solution**: Verify your project targets iOS 17.0+ or macOS 14.0+.

**Problem**: Framework not found
**Solution**: Clean your build folder and rebuild the XCFramework.

### Runtime Issues

**Problem**: Crashes on startup
**Solution**: Ensure all required iOS targets are included in the XCFramework and that you're running on a supported iOS version.

**Problem**: Storage errors
**Solution**: Verify your storage provider configuration and file system permissions. Ensure your `GroupStateStorage` implementation properly handles all required methods.

**Problem**: Groups not persisting across app launches
**Solution**: Ensure `writeToStorage()` is called after group operations and that your storage implementation correctly saves data to persistent storage.

**Problem**: Memory issues with large groups
**Solution**: Implement efficient storage with proper cleanup of old epoch data. Consider using SQLite or Core Data for large-scale deployments.

## Contributing

Contributions are welcome! Please see the main [mls-rs contributing guide](../../CONTRIBUTING.md) for details.

## License

This project is licensed under either of

- Apache License, Version 2.0, ([LICENSE-APACHE](../../LICENSE-apache) or http://www.apache.org/licenses/LICENSE-2.0)
- MIT license ([LICENSE-MIT](../../LICENSE-mit) or http://opensource.org/licenses/MIT)

at your option.
