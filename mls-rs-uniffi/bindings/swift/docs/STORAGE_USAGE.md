# Storage Usage Guide

This guide covers persistent storage options for MLS-RS Swift bindings, including SwiftData integration, custom storage providers, and storage management best practices.

## Overview

The MLS-RS Swift bindings provide flexible storage options for persisting:

- **Group State**: Complete group configuration and member information
- **Epoch Data**: Historical key material and protocol state
- **Client Configuration**: Persistent client settings and preferences
- **Key Material**: Signature keypairs and derived keys

## Storage Backends

### 1. Default In-Memory Storage

For testing and temporary usage:

```swift
// Default configuration uses in-memory storage
let config = clientConfigDefault()
let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)

// Data is lost when the app terminates
```

### 2. SwiftData Storage (Recommended)

SwiftData provides modern, type-safe persistence:

```swift
import SwiftData
import MlsRs

// Create SwiftData storage
let storage = SwiftDataStorage(inMemory: false) // Persistent storage
// let storage = SwiftDataStorage(inMemory: true)  // In-memory for testing

// Use with client configuration
let config = ClientConfig(storage: storage)
let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
```

#### SwiftData Configuration Options

```swift
// Custom model container configuration
let container = try ModelContainer(for: [
    GroupStateModel.self,
    EpochDataModel.self
], configurations: ModelConfiguration(
    url: URL.documentsDirectory.appending(path: "mls-data.sqlite"),
    isStoredInMemoryOnly: false
))

let storage = SwiftDataStorage(container: container)
```

### 3. Custom Storage Providers

Implement the `StorageProvider` protocol for custom backends:

```swift
class CustomFileStorage: StorageProvider {
    private let baseURL: URL
    
    init(baseURL: URL) {
        self.baseURL = baseURL
    }
    
    func storeGroupState(groupId: Data, state: Data) throws {
        let url = baseURL.appendingPathComponent("group-\(groupId.base64EncodedString()).mls")
        try state.write(to: url)
    }
    
    func loadGroupState(groupId: Data) throws -> Data? {
        let url = baseURL.appendingPathComponent("group-\(groupId.base64EncodedString()).mls")
        return try? Data(contentsOf: url)
    }
    
    func deleteGroupState(groupId: Data) throws {
        let url = baseURL.appendingPathComponent("group-\(groupId.base64EncodedString()).mls")
        try FileManager.default.removeItem(at: url)
    }
    
    // Implement other required methods...
}

// Use custom storage
let customStorage = CustomFileStorage(baseURL: .documentsDirectory)
let config = ClientConfig(storage: customStorage)
```

## SwiftData Integration Deep Dive

### Setting Up SwiftData Storage

```swift
import SwiftData
import MlsRs

class MLSDataManager {
    let storage: SwiftDataStorage
    let modelContainer: ModelContainer
    
    init() throws {
        // Configure SwiftData model container
        modelContainer = try ModelContainer(for: [
            GroupStateModel.self,
            EpochDataModel.self
        ])
        
        // Create MLS storage
        storage = SwiftDataStorage(container: modelContainer)
    }
    
    func createClient(id: String, cipherSuite: CipherSuite) throws -> Client {
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let config = ClientConfig(storage: storage)
        
        return Client(
            id: Data(id.utf8),
            signatureKeypair: keypair,
            clientConfig: config
        )
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI
import SwiftData
import MlsRs

@main
struct MLSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [GroupStateModel.self, EpochDataModel.self])
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var mlsManager: MLSDataManager?
    
    var body: some View {
        VStack {
            // Your MLS UI here
        }
        .task {
            do {
                mlsManager = try MLSDataManager(modelContext: modelContext)
            } catch {
                print("Failed to initialize MLS: \(error)")
            }
        }
    }
}
```

### Storage Statistics and Monitoring

```swift
// Get storage statistics
let stats = try storage.getStorageStats()
print("Groups: \(stats.groupCount)")
print("Total epochs: \(stats.epochCount)")
print("Storage size: \(stats.storageSize) bytes")

// Monitor storage growth
class StorageMonitor {
    private let storage: SwiftDataStorage
    private var timer: Timer?
    
    init(storage: SwiftDataStorage) {
        self.storage = storage
        startMonitoring()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            self.checkStorageUsage()
        }
    }
    
    private func checkStorageUsage() {
        do {
            let stats = try storage.getStorageStats()
            if stats.storageSize > 100 * 1024 * 1024 { // 100MB
                print("⚠️ Storage usage high: \(stats.storageSize / 1024 / 1024)MB")
                // Consider cleanup
            }
        } catch {
            print("Failed to check storage: \(error)")
        }
    }
}
```

## Storage Operations

### Group State Management

```swift
// Groups are automatically persisted when state changes
let group = try client.createGroup(groupId: nil)

// Manually save state
try group.writeToStorage()

// Load existing group from storage
let existingGroups = try client.loadGroupsFromStorage()
for groupInfo in existingGroups {
    print("Found group: \(groupInfo.groupId.base64EncodedString())")
}
```

### Epoch Data Management

```swift
// Configure epoch retention policy
let config = ClientConfig(
    storage: storage,
    epochRetentionPolicy: .keepLast(100) // Keep last 100 epochs
)

// Manual epoch cleanup
try storage.cleanupOldEpochs(olderThan: Date().addingTimeInterval(-30 * 24 * 3600)) // 30 days
```

### Backup and Export

```swift
// Export group state for backup
func exportGroupState(group: Group) throws -> Data {
    return try group.exportState()
}

// Import group state from backup
func importGroupState(client: Client, stateData: Data) throws -> Group {
    return try client.importGroup(stateData: stateData)
}

// Full storage backup
func backupAllGroups(client: Client) throws -> [String: Data] {
    var backup: [String: Data] = [:]
    let groups = try client.loadGroupsFromStorage()
    
    for groupInfo in groups {
        let groupId = groupInfo.groupId.base64EncodedString()
        backup[groupId] = try exportGroupState(group: groupInfo.group)
    }
    
    return backup
}
```

## Data Migration

### Version Migration

```swift
class MLSDataMigrator {
    static func migrateIfNeeded(storage: SwiftDataStorage) throws {
        let currentVersion = try storage.getDataVersion()
        
        switch currentVersion {
        case .v1:
            try migrateV1ToV2(storage: storage)
            fallthrough
        case .v2:
            try migrateV2ToV3(storage: storage)
        case .current:
            break // No migration needed
        }
    }
    
    private static func migrateV1ToV2(storage: SwiftDataStorage) throws {
        // Perform migration logic
        print("Migrating storage from v1 to v2...")
        // ... migration code ...
        try storage.setDataVersion(.v2)
    }
}
```

### Storage Compaction

```swift
// Compact storage to reclaim space
func compactStorage(storage: SwiftDataStorage) throws {
    print("Starting storage compaction...")
    
    // Remove orphaned data
    try storage.removeOrphanedEpochs()
    
    // Vacuum database if using SQLite backend
    try storage.vacuum()
    
    let statsAfter = try storage.getStorageStats()
    print("Compaction complete. Size: \(statsAfter.storageSize) bytes")
}
```

## Performance Optimization

### Batch Operations

```swift
// Batch storage operations for better performance
try storage.performBatch { batchStorage in
    for group in groups {
        try group.writeToStorage(using: batchStorage)
    }
}
```

### Caching Strategy

```swift
class CachedStorageProvider: StorageProvider {
    private let underlying: StorageProvider
    private var cache: [Data: Data] = [:]
    private let cacheQueue = DispatchQueue(label: "mls.storage.cache")
    
    init(underlying: StorageProvider) {
        self.underlying = underlying
    }
    
    func loadGroupState(groupId: Data) throws -> Data? {
        return try cacheQueue.sync {
            if let cached = cache[groupId] {
                return cached
            }
            
            let data = try underlying.loadGroupState(groupId: groupId)
            if let data = data {
                cache[groupId] = data
            }
            return data
        }
    }
    
    func storeGroupState(groupId: Data, state: Data) throws {
        try underlying.storeGroupState(groupId: groupId, state: state)
        cacheQueue.sync {
            cache[groupId] = state
        }
    }
}
```

### Background Processing

```swift
class BackgroundStorageManager {
    private let storage: SwiftDataStorage
    private let queue = DispatchQueue(label: "mls.storage.background", qos: .utility)
    
    init(storage: SwiftDataStorage) {
        self.storage = storage
    }
    
    func scheduleCleanup() {
        queue.async {
            do {
                try self.storage.cleanupOldEpochs(olderThan: Date().addingTimeInterval(-7 * 24 * 3600))
                print("Background cleanup completed")
            } catch {
                print("Background cleanup failed: \(error)")
            }
        }
    }
    
    func scheduledBackup(to url: URL) {
        queue.async {
            do {
                try self.storage.backup(to: url)
                print("Background backup completed")
            } catch {
                print("Background backup failed: \(error)")
            }
        }
    }
}
```

## Security Considerations

### Storage Encryption

```swift
// Use iOS/macOS keychain for sensitive data
import Security

class SecureStorageProvider: StorageProvider {
    private func storeInKeychain(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw StorageError("Failed to store in keychain: \(status)")
        }
    }
    
    private func loadFromKeychain(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw StorageError("Failed to load from keychain: \(status)")
        }
        
        return result as? Data
    }
}
```

### File Protection

```swift
// Enable file protection for on-disk storage
func configureFileProtection(for url: URL) throws {
    try (url as NSURL).setResourceValue(
        FileProtectionType.complete,
        forKey: .fileProtectionKey
    )
}
```

## Testing Storage

### Unit Testing with In-Memory Storage

```swift
import XCTest
@testable import MlsRs

class StorageTests: XCTestCase {
    var storage: SwiftDataStorage!
    
    override func setUp() {
        super.setUp()
        // Use in-memory storage for testing
        storage = SwiftDataStorage(inMemory: true)
    }
    
    func testGroupStateStorage() throws {
        let groupId = Data("test-group".utf8)
        let stateData = Data("test-state".utf8)
        
        // Store
        try storage.storeGroupState(groupId: groupId, state: stateData)
        
        // Load
        let loaded = try storage.loadGroupState(groupId: groupId)
        XCTAssertEqual(loaded, stateData)
        
        // Delete
        try storage.deleteGroupState(groupId: groupId)
        let afterDelete = try storage.loadGroupState(groupId: groupId)
        XCTAssertNil(afterDelete)
    }
}
```

### Performance Testing

```swift
func testStoragePerformance() throws {
    let storage = SwiftDataStorage(inMemory: true)
    
    measure {
        for i in 0..<1000 {
            let groupId = Data("group-\(i)".utf8)
            let state = Data("state-\(i)".utf8)
            try! storage.storeGroupState(groupId: groupId, state: state)
        }
    }
}
```

## Best Practices

### 1. Storage Selection

- **Use SwiftData** for most iOS/macOS applications
- **Use in-memory storage** for testing and temporary sessions
- **Implement custom storage** for specialized requirements (e.g., server applications)

### 2. Data Lifecycle Management

```swift
// Regular cleanup schedule
class StorageMaintenanceManager {
    private let storage: SwiftDataStorage
    private let timer: Timer
    
    init(storage: SwiftDataStorage) {
        self.storage = storage
        
        // Schedule daily maintenance
        self.timer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { _ in
            Task {
                await self.performMaintenance()
            }
        }
    }
    
    private func performMaintenance() async {
        do {
            // Remove old epochs (older than 30 days)
            try storage.cleanupOldEpochs(olderThan: Date().addingTimeInterval(-30 * 24 * 3600))
            
            // Compact storage
            try storage.vacuum()
            
            print("Storage maintenance completed")
        } catch {
            print("Storage maintenance failed: \(error)")
        }
    }
}
```

### 3. Error Handling

```swift
enum StorageError: Error, LocalizedError {
    case notFound
    case corruptedData
    case insufficientSpace
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Storage item not found"
        case .corruptedData:
            return "Storage data is corrupted"
        case .insufficientSpace:
            return "Insufficient storage space"
        case .accessDenied:
            return "Storage access denied"
        }
    }
}
```

### 4. Monitoring and Alerting

```swift
class StorageHealthMonitor {
    private let storage: SwiftDataStorage
    
    init(storage: SwiftDataStorage) {
        self.storage = storage
    }
    
    func checkHealth() -> StorageHealth {
        do {
            let stats = try storage.getStorageStats()
            
            // Check storage size
            if stats.storageSize > 500 * 1024 * 1024 { // 500MB
                return .warning("Storage size exceeds 500MB")
            }
            
            // Check epoch count
            if stats.epochCount > 10000 {
                return .warning("Too many epochs stored")
            }
            
            return .healthy
        } catch {
            return .error("Failed to check storage health: \(error)")
        }
    }
}

enum StorageHealth {
    case healthy
    case warning(String)
    case error(String)
}
```

## Troubleshooting

### Common Storage Issues

1. **Storage corruption**: Implement data validation and backup strategies
2. **Performance degradation**: Regular cleanup and compaction
3. **Disk space issues**: Monitor usage and implement retention policies
4. **Migration failures**: Comprehensive testing and rollback procedures

### Debug Logging

```swift
#if DEBUG
extension SwiftDataStorage {
    func debugDump() {
        print("=== Storage Debug Info ===")
        do {
            let stats = try getStorageStats()
            print("Groups: \(stats.groupCount)")
            print("Epochs: \(stats.epochCount)")
            print("Size: \(stats.storageSize) bytes")
        } catch {
            print("Failed to get stats: \(error)")
        }
        print("========================")
    }
}
#endif
```

## Next Steps

- [**Performance Guide**](PERFORMANCE.md) - Optimization techniques
- [**Security Guide**](SECURITY.md) - Security best practices  
- [**Advanced Features**](ADVANCED_FEATURES.md) - Complex group operations
- [**Crypto Providers**](CRYPTO_PROVIDERS.md) - Cryptographic configuration
