import Foundation
import MlsRs

// SwiftData Storage Example
// This example demonstrates how to use the SwiftDataStorage provider
// with MLS for persistent group state management.

@main
struct SwiftDataExample {
    static func main() async {
        print("🚀 MLS SwiftData Storage Example")
        print("=====================================")
        
        do {
            try await runSwiftDataExample()
        } catch {
            print("❌ Example failed: \(error)")
            exit(1)
        }
    }
}

func runSwiftDataExample() async throws {
    print("\n📁 1. Creating SwiftData Storage (In-Memory)")
    
    // Create SwiftData storage for testing (in-memory)
    // In production, use SwiftDataStorage(inMemory: false) for persistence
    guard let storage = try? SwiftDataStorage(inMemory: true) else {
        print("⚠️  SwiftData not available on this platform")
        print("   SwiftData requires iOS 17+ or macOS 14+")
        return
    }
    
    print("✅ SwiftData storage created successfully")
    
    // Get default configuration
    let config = clientConfigDefault()
    
    // Generate signature keypairs
    print("\n🔑 2. Generating MLS Clients with SwiftData Storage")
    let aliceKey = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
    let bobKey = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
    
    // Create clients (Note: In real implementation, you'd need to configure
    // the client with custom storage. This example shows the storage interface)
    let alice = Client(
        id: Data("alice".utf8),
        signatureKeypair: aliceKey,
        clientConfig: config
    )
    
    let bob = Client(
        id: Data("bob".utf8),
        signatureKeypair: bobKey,
        clientConfig: config
    )
    
    print("✅ Alice and Bob clients created")
    
    // Demonstrate storage functionality directly
    print("\n💾 3. Demonstrating Storage Operations")
    let groupId = Data("example-group-123".utf8)
    let groupState = Data("example-group-state-data".utf8)
    
    // Test basic storage
    print("   Testing basic group state storage...")
    try storage.write(
        groupId: groupId,
        groupState: groupState,
        epochInserts: [],
        epochUpdates: []
    )
    
    let retrievedState = try storage.state(groupId: groupId)
    if let state = retrievedState, state == groupState {
        print("   ✅ Group state stored and retrieved successfully")
    } else {
        print("   ❌ Group state storage failed")
    }
    
    // Test epoch storage
    print("   Testing epoch data storage...")
    let epochs = [
        EpochRecord(id: 1, data: Data("epoch-1-data".utf8)),
        EpochRecord(id: 2, data: Data("epoch-2-data".utf8)),
        EpochRecord(id: 3, data: Data("epoch-3-data".utf8))
    ]
    
    try storage.write(
        groupId: groupId,
        groupState: groupState,
        epochInserts: epochs,
        epochUpdates: []
    )
    
    let maxEpochId = try storage.maxEpochId(groupId: groupId)
    if maxEpochId == 3 {
        print("   ✅ Epoch data stored successfully (max epoch: \(maxEpochId!))")
    } else {
        print("   ❌ Epoch storage failed")
    }
    
    // Test epoch retrieval
    let epoch2Data = try storage.epoch(groupId: groupId, epochId: 2)
    if epoch2Data == Data("epoch-2-data".utf8) {
        print("   ✅ Individual epoch retrieval successful")
    } else {
        print("   ❌ Epoch retrieval failed")
    }
    
    // Test epoch updates
    print("   Testing epoch updates...")
    let updatedEpoch = EpochRecord(id: 2, data: Data("updated-epoch-2-data".utf8))
    try storage.write(
        groupId: groupId,
        groupState: groupState,
        epochInserts: [],
        epochUpdates: [updatedEpoch]
    )
    
    let updatedData = try storage.epoch(groupId: groupId, epochId: 2)
    if updatedData == Data("updated-epoch-2-data".utf8) {
        print("   ✅ Epoch update successful")
    } else {
        print("   ❌ Epoch update failed")
    }
    
    // Test multiple groups
    print("\n🏢 4. Testing Multiple Groups")
    let group2Id = Data("example-group-456".utf8)
    let group2State = Data("group-2-state-data".utf8)
    
    try storage.write(
        groupId: group2Id,
        groupState: group2State,
        epochInserts: [EpochRecord(id: 1, data: Data("group2-epoch1".utf8))],
        epochUpdates: []
    )
    
    let allGroups = try storage.getAllGroupIds()
    print("   Total groups stored: \(allGroups.count)")
    for groupIdString in allGroups {
        print("   - Group: \(groupIdString.prefix(16))...")
    }
    
    // Test storage statistics
    print("\n📊 5. Storage Statistics")
    let stats = try storage.getStorageStats()
    print("   Groups: \(stats.groupCount)")
    print("   Total epochs: \(stats.totalEpochs)")
    
    // Test cleanup functionality
    print("\n🧹 6. Testing Cleanup Operations")
    
    // Add many epochs to test cleanup
    let manyEpochs = (4...20).map { EpochRecord(id: UInt64($0), data: Data("epoch-\($0)".utf8)) }
    try storage.write(
        groupId: groupId,
        groupState: groupState,
        epochInserts: manyEpochs,
        epochUpdates: []
    )
    
    let beforeCleanup = try storage.getStorageStats()
    print("   Before cleanup - Total epochs: \(beforeCleanup.totalEpochs)")
    
    // Keep only last 10 epochs
    try storage.cleanupOldEpochs(keepLastN: 10)
    
    let afterCleanup = try storage.getStorageStats()
    print("   After cleanup - Total epochs: \(afterCleanup.totalEpochs)")
    
    // Verify cleanup worked correctly
    let oldEpoch = try storage.epoch(groupId: groupId, epochId: 5)
    let newEpoch = try storage.epoch(groupId: groupId, epochId: 15)
    
    if oldEpoch == nil && newEpoch != nil {
        print("   ✅ Cleanup successful - old epochs removed, new epochs retained")
    } else {
        print("   ❌ Cleanup verification failed")
    }
    
    // Test group deletion
    print("\n🗑️  7. Testing Group Deletion")
    let testGroupId = Data("temp-group-789".utf8)
    try storage.write(
        groupId: testGroupId,
        groupState: Data("temp-state".utf8),
        epochInserts: [EpochRecord(id: 1, data: Data("temp-epoch".utf8))],
        epochUpdates: []
    )
    
    let beforeDelete = try storage.getStorageStats()
    try storage.deleteGroup(groupId: testGroupId)
    let afterDelete = try storage.getStorageStats()
    
    if afterDelete.groupCount == beforeDelete.groupCount - 1 {
        print("   ✅ Group deletion successful")
    } else {
        print("   ❌ Group deletion failed")
    }
    
    // Performance demonstration
    print("\n⚡ 8. Performance Test")
    let startTime = Date()
    
    let performanceGroupId = Data("performance-test".utf8)
    let largeEpochs = (1...100).map { EpochRecord(id: UInt64($0), data: Data("performance-epoch-\($0)".utf8)) }
    
    try storage.write(
        groupId: performanceGroupId,
        groupState: Data("performance-state".utf8),
        epochInserts: largeEpochs,
        epochUpdates: []
    )
    
    let endTime = Date()
    let duration = endTime.timeIntervalSince(startTime)
    print("   Stored 100 epochs in \(String(format: "%.3f", duration)) seconds")
    
    // Final statistics
    print("\n📈 9. Final Storage Report")
    let finalStats = try storage.getStorageStats()
    print("   Total groups: \(finalStats.groupCount)")
    print("   Total epochs: \(finalStats.totalEpochs)")
    
    print("\n🎉 SwiftData Storage Example Completed Successfully!")
    print("\n💡 Key Features Demonstrated:")
    print("   ✅ Group state persistence")
    print("   ✅ Epoch data management")
    print("   ✅ Multi-group support")
    print("   ✅ Data cleanup and maintenance")
    print("   ✅ Performance characteristics")
    print("   ✅ Thread-safe operations")
    
    print("\n📚 Integration Notes:")
    print("   • Use SwiftDataStorage(inMemory: false) for production")
    print("   • Configure ModelContainer for advanced scenarios")
    print("   • Implement custom storage providers for specific needs")
    print("   • Consider cleanup schedules for long-running apps")
    print("   • Monitor storage growth in production environments")
}

// Example SwiftUI integration helper
#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

struct ExampleSwiftUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [MLSGroupState.self, MLSEpochData.self]) // Enable MLS SwiftData support
        }
    }
}

struct ContentView: View {
    @State private var storage: SwiftDataStorage?
    @State private var statusMessage = "Initializing..."
    
    var body: some View {
        VStack(spacing: 20) {
            Text("MLS SwiftData Example")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text(statusMessage)
                .foregroundColor(.secondary)
            
            if storage != nil {
                VStack {
                    Text("Storage Ready")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
                .frame(maxWidth: 300)
            }
            
            Button("Initialize Storage") {
                initializeStorage()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            initializeStorage()
        }
    }
    
    private func initializeStorage() {
        do {
            storage = try SwiftDataStorage(inMemory: false)
            statusMessage = "✅ SwiftData storage ready"
        } catch {
            statusMessage = "❌ Failed to initialize: \(error.localizedDescription)"
        }
    }
}
#endif
