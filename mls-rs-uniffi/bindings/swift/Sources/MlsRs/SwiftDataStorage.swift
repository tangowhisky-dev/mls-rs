import Foundation
import SwiftData

// MARK: - SwiftData Models

/// SwiftData model for storing MLS group state data.
///
/// This model represents persistent storage for MLS group state information,
/// including encrypted group configuration and member data. Each group is
/// uniquely identified by its `groupId` and stores the complete serialized
/// group state required for MLS operations.
///
/// - Note: This model is automatically managed by SwiftData and supports
///   querying with `#Predicate` and `FetchDescriptor`.
@Model
public class MLSGroupState {
    @Attribute(.unique) public var groupId: String
    public var groupState: Data
    public var createdAt: Date
    public var updatedAt: Date
    
    public init(groupId: String, groupState: Data) {
        self.groupId = groupId
        self.groupState = groupState
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// SwiftData model for storing MLS epoch data.
///
/// This model stores historical epoch information for MLS groups, enabling
/// message decryption from previous epochs and maintaining forward secrecy.
/// Each epoch represents a specific cryptographic state of the group.
///
/// The `id` field combines `groupId` and `epochId` to ensure uniqueness
/// across all groups and epochs in the data store.
///
/// - Important: Epoch data should be cleaned up periodically to prevent
///   unlimited storage growth. Use `cleanupOldEpochs(keepLastN:)` for maintenance.
@Model
public class MLSEpochData {
    @Attribute(.unique) public var id: String // groupId + epochId combination
    public var groupId: String
    public var epochId: UInt64
    public var epochData: Data
    public var createdAt: Date
    
    public init(groupId: String, epochId: UInt64, epochData: Data) {
        self.groupId = groupId
        self.epochId = epochId
        self.epochData = epochData
        self.createdAt = Date()
        self.id = "\(groupId)_\(epochId)"
    }
}

// MARK: - SwiftData Storage Provider

/// SwiftData-based storage provider for MLS group state and epoch management.
///
/// `SwiftDataStorage` implements the `GroupStateStorage` protocol using Apple's
/// SwiftData framework, providing native iOS/macOS persistence with excellent
/// SwiftUI integration capabilities.
///
/// ## Features
/// - **Thread-Safe Operations**: All storage operations are coordinated through a serial queue
/// - **SwiftUI Integration**: Native `@Query` support for reactive UI updates
/// - **Automatic Schema Management**: SwiftData handles database schema and migrations
/// - **Performance Optimized**: Efficient queries using `#Predicate` and `FetchDescriptor`
/// - **Memory Management**: Optional in-memory storage for testing scenarios
///
/// ## Usage
///
/// ```swift
/// // Basic usage
/// let storage = try SwiftDataStorage(inMemory: false)
/// let config = ClientConfig(groupStateStorage: storage, useRatchetTreeExtension: true)
/// let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
///
/// // SwiftUI integration
/// @main
/// struct MyApp: App {
///     var body: some Scene {
///         WindowGroup {
///             ContentView()
///                 .modelContainer(for: [MLSGroupState.self, MLSEpochData.self])
///         }
///     }
/// }
/// ```
///
/// ## Platform Requirements
/// - iOS 17.0+ / macOS 14.0+
/// - SwiftData framework
///
/// - Important: This storage provider is designed for production use with automatic
///   persistence, schema management, and CloudKit sync support when configured.
public class SwiftDataStorage: GroupStateStorage {
    
    private let modelContainer: ModelContainer
    private let serialQueue = DispatchQueue(label: "SwiftDataStorage", qos: .userInitiated)
    
    /// Initialize SwiftData storage with optional configuration
    /// - Parameter inMemory: If true, uses in-memory storage for testing
    public init(inMemory: Bool = false) throws {
        let schema = Schema([MLSGroupState.self, MLSEpochData.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            allowsSave: true
        )
        
        self.modelContainer = try ModelContainer(for: schema, configurations: [configuration])
    }
    
    /// Initialize with custom ModelContainer (advanced usage)
    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }
    
    // MARK: - GroupStateStorage Implementation
    
    public func state(groupId: Data) throws -> Data? {
        return try serialQueue.sync {
            let context = ModelContext(modelContainer)
            let groupIdString = groupId.base64EncodedString()
            
            let predicate = #Predicate<MLSGroupState> { groupState in
                groupState.groupId == groupIdString
            }
            
            let descriptor = FetchDescriptor(predicate: predicate)
            let groups = try context.fetch(descriptor)
            
            return groups.first?.groupState
        }
    }
    
    public func epoch(groupId: Data, epochId: UInt64) throws -> Data? {
        return try serialQueue.sync {
            let context = ModelContext(modelContainer)
            let groupIdString = groupId.base64EncodedString()
            let epochIdString = "\(groupIdString)_\(epochId)"
            
            let predicate = #Predicate<MLSEpochData> { epochData in
                epochData.id == epochIdString
            }
            
            let descriptor = FetchDescriptor(predicate: predicate)
            let epochs = try context.fetch(descriptor)
            
            return epochs.first?.epochData
        }
    }
    
    public func write(
        groupId: Data,
        groupState: Data,
        epochInserts: [EpochRecord],
        epochUpdates: [EpochRecord]
    ) throws {
        try serialQueue.sync {
            let context = ModelContext(modelContainer)
            let groupIdString = groupId.base64EncodedString()
            
            // Update or insert group state
            let groupPredicate = #Predicate<MLSGroupState> { group in
                group.groupId == groupIdString
            }
            
            let groupDescriptor = FetchDescriptor(predicate: groupPredicate)
            let existingGroups = try context.fetch(groupDescriptor)
            
            if let existingGroup = existingGroups.first {
                existingGroup.groupState = groupState
                existingGroup.updatedAt = Date()
            } else {
                let newGroup = MLSGroupState(groupId: groupIdString, groupState: groupState)
                context.insert(newGroup)
            }
            
            // Process epoch inserts
            for epoch in epochInserts {
                let epochData = MLSEpochData(
                    groupId: groupIdString,
                    epochId: epoch.id,
                    epochData: epoch.data
                )
                context.insert(epochData)
            }
            
            // Process epoch updates
            for epoch in epochUpdates {
                let epochIdString = "\(groupIdString)_\(epoch.id)"
                
                let epochPredicate = #Predicate<MLSEpochData> { epochData in
                    epochData.id == epochIdString
                }
                
                let epochDescriptor = FetchDescriptor(predicate: epochPredicate)
                let existingEpochs = try context.fetch(epochDescriptor)
                
                if let existingEpoch = existingEpochs.first {
                    existingEpoch.epochData = epoch.data
                } else {
                    let newEpoch = MLSEpochData(
                        groupId: groupIdString,
                        epochId: epoch.id,
                        epochData: epoch.data
                    )
                    context.insert(newEpoch)
                }
            }
            
            // Save changes
            try context.save()
        }
    }
    
    public func maxEpochId(groupId: Data) throws -> UInt64? {
        return try serialQueue.sync {
            let context = ModelContext(modelContainer)
            let groupIdString = groupId.base64EncodedString()
            
            let predicate = #Predicate<MLSEpochData> { epochData in
                epochData.groupId == groupIdString
            }
            
            var descriptor = FetchDescriptor(
                predicate: predicate,
                sortBy: [SortDescriptor(\.epochId, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            
            let epochs = try context.fetch(descriptor)
            return epochs.first?.epochId
        }
    }
    
    // MARK: - Additional Utility Methods
    
    /// Get all stored group IDs
    public func getAllGroupIds() throws -> [String] {
        return try serialQueue.sync {
            let context = ModelContext(modelContainer)
            let descriptor = FetchDescriptor<MLSGroupState>()
            let groups = try context.fetch(descriptor)
            return groups.map { $0.groupId }
        }
    }
    
    /// Clean up old epoch data (keep only last N epochs per group)
    public func cleanupOldEpochs(keepLastN: Int = 10) throws {
        try serialQueue.sync {
            let context = ModelContext(modelContainer)
            
            // Get group IDs directly without calling getAllGroupIds() to avoid deadlock
            let groupDescriptor = FetchDescriptor<MLSGroupState>()
            let groups = try context.fetch(groupDescriptor)
            let groupIds = groups.map { $0.groupId }
            
            for groupId in groupIds {
                let predicate = #Predicate<MLSEpochData> { epochData in
                    epochData.groupId == groupId
                }
                
                let descriptor = FetchDescriptor(
                    predicate: predicate,
                    sortBy: [SortDescriptor(\.epochId, order: .reverse)]
                )
                
                let epochs = try context.fetch(descriptor)
                
                // Delete old epochs beyond the keepLastN count
                if epochs.count > keepLastN {
                    let epochsToDelete = Array(epochs.dropFirst(keepLastN))
                    for epoch in epochsToDelete {
                        context.delete(epoch)
                    }
                }
            }
            
            try context.save()
        }
    }
    
    /// Delete all data for a specific group
    public func deleteGroup(groupId: Data) throws {
        try serialQueue.sync {
            let context = ModelContext(modelContainer)
            let groupIdString = groupId.base64EncodedString()
            
            // Delete group state
            let groupPredicate = #Predicate<MLSGroupState> { group in
                group.groupId == groupIdString
            }
            let groupDescriptor = FetchDescriptor(predicate: groupPredicate)
            let groups = try context.fetch(groupDescriptor)
            for group in groups {
                context.delete(group)
            }
            
            // Delete epoch data
            let epochPredicate = #Predicate<MLSEpochData> { epochData in
                epochData.groupId == groupIdString
            }
            let epochDescriptor = FetchDescriptor(predicate: epochPredicate)
            let epochs = try context.fetch(epochDescriptor)
            for epoch in epochs {
                context.delete(epoch)
            }
            
            try context.save()
        }
    }
    
    /// Get storage statistics
    public func getStorageStats() throws -> (groupCount: Int, totalEpochs: Int) {
        return try serialQueue.sync {
            let context = ModelContext(modelContainer)
            let groupDescriptor = FetchDescriptor<MLSGroupState>()
            let epochDescriptor = FetchDescriptor<MLSEpochData>()
            
            let groupCount = try context.fetch(groupDescriptor).count
            let epochCount = try context.fetch(epochDescriptor).count
            
            return (groupCount, epochCount)
        }
    }
}

// MARK: - SwiftUI Integration Helpers

#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

/// SwiftUI View modifier for configuring SwiftData with MLS storage
@available(iOS 17.0, macOS 14.0, *)
public struct MLSDataContainer: ViewModifier {
    let inMemory: Bool
    
    public init(inMemory: Bool = false) {
        self.inMemory = inMemory
    }
    
    public func body(content: Content) -> some View {
        content
            .modelContainer(for: [MLSGroupState.self, MLSEpochData.self], inMemory: inMemory)
    }
}

@available(iOS 17.0, macOS 14.0, *)
public extension View {
    /// Add MLS SwiftData support to your SwiftUI app
    func mlsDataContainer(inMemory: Bool = false) -> some View {
        modifier(MLSDataContainer(inMemory: inMemory))
    }
}

/// SwiftUI View for displaying MLS storage statistics
@available(iOS 17.0, macOS 14.0, *)
public struct MLSStorageStatsView: View {
    @Query private var groups: [MLSGroupState]
    @Query private var epochs: [MLSEpochData]
    
    public init() {}
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MLS Storage Statistics")
                .font(.headline)
            
            HStack {
                Text("Groups:")
                Spacer()
                Text("\(groups.count)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Epochs:")
                Spacer()
                Text("\(epochs.count)")
                    .foregroundColor(.secondary)
            }
            
            if !groups.isEmpty {
                Text("Latest Activity:")
                    .font(.subheadline)
                    .padding(.top)
                
                ForEach(groups.sorted(by: { $0.updatedAt > $1.updatedAt }).prefix(3), id: \.groupId) { group in
                    HStack {
                        Text(group.groupId.prefix(8) + "...")
                            .font(.caption.monospaced())
                        Spacer()
                        Text(group.updatedAt, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(8)
    }
}
#endif
