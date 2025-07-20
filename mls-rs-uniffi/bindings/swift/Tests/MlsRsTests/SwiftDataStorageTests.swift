import XCTest
@testable import MlsRs

// Only run SwiftData tests on supported platforms
#if os(iOS) && swift(>=5.9) || os(macOS) && swift(>=5.9)
import SwiftData

final class SwiftDataStorageTests: XCTestCase {
    
    var storage: SwiftDataStorage!
    var testGroupId: Data!
    var testGroupState: Data!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory storage for testing
        storage = try SwiftDataStorage(inMemory: true)
        testGroupId = Data("test-group-123".utf8)
        testGroupState = Data("test-group-state-data".utf8)
    }
    
    override func tearDown() async throws {
        storage = nil
        testGroupId = nil
        testGroupState = nil
        try await super.tearDown()
    }
    
    // MARK: - Basic Storage Tests
    
    func testStorageInitialization() throws {
        // Test in-memory initialization
        let inMemoryStorage = try SwiftDataStorage(inMemory: true)
        XCTAssertNotNil(inMemoryStorage)
        
        // Test persistent initialization (skip on CI)
        if ProcessInfo.processInfo.environment["CI"] == nil {
            let persistentStorage = try SwiftDataStorage(inMemory: false)
            XCTAssertNotNil(persistentStorage)
        }
    }
    
    func testGroupStateStorage() throws {
        // Initially no state should exist
        let initialState = try storage.state(groupId: testGroupId)
        XCTAssertNil(initialState)
        
        // Write group state
        try storage.write(
            groupId: testGroupId,
            groupState: testGroupState,
            epochInserts: [],
            epochUpdates: []
        )
        
        // Read back the state
        let retrievedState = try storage.state(groupId: testGroupId)
        XCTAssertNotNil(retrievedState)
        XCTAssertEqual(retrievedState, testGroupState)
    }
    
    func testEpochDataStorage() throws {
        let epochId: UInt64 = 1
        let epochData = Data("epoch-1-data".utf8)
        let epochRecord = EpochRecord(id: epochId, data: epochData)
        
        // Initially no epoch should exist
        let initialEpoch = try storage.epoch(groupId: testGroupId, epochId: epochId)
        XCTAssertNil(initialEpoch)
        
        // Write epoch data
        try storage.write(
            groupId: testGroupId,
            groupState: testGroupState,
            epochInserts: [epochRecord],
            epochUpdates: []
        )
        
        // Read back the epoch
        let retrievedEpoch = try storage.epoch(groupId: testGroupId, epochId: epochId)
        XCTAssertNotNil(retrievedEpoch)
        XCTAssertEqual(retrievedEpoch, epochData)
    }
    
    func testMaxEpochId() throws {
        // Initially no max epoch ID should exist
        let initialMaxId = try storage.maxEpochId(groupId: testGroupId)
        XCTAssertNil(initialMaxId)
        
        // Insert multiple epochs
        let epochs = [
            EpochRecord(id: 1, data: Data("epoch-1".utf8)),
            EpochRecord(id: 3, data: Data("epoch-3".utf8)),
            EpochRecord(id: 2, data: Data("epoch-2".utf8))
        ]
        
        try storage.write(
            groupId: testGroupId,
            groupState: testGroupState,
            epochInserts: epochs,
            epochUpdates: []
        )
        
        // Should return the highest epoch ID
        let maxId = try storage.maxEpochId(groupId: testGroupId)
        XCTAssertEqual(maxId, 3)
    }
    
    func testStorageStats() throws {
        // Initially empty
        let initialStats = try storage.getStorageStats()
        XCTAssertEqual(initialStats.groupCount, 0)
        XCTAssertEqual(initialStats.totalEpochs, 0)
        
        // Add data
        let epochs = [
            EpochRecord(id: 1, data: Data("epoch-1".utf8)),
            EpochRecord(id: 2, data: Data("epoch-2".utf8))
        ]
        
        try storage.write(
            groupId: testGroupId,
            groupState: testGroupState,
            epochInserts: epochs,
            epochUpdates: []
        )
        
        // Check stats
        let stats = try storage.getStorageStats()
        XCTAssertEqual(stats.groupCount, 1)
        XCTAssertEqual(stats.totalEpochs, 2)
    }
}

#else
// Placeholder test for unsupported platforms
final class SwiftDataStorageTests: XCTestCase {
    func testUnsupportedPlatform() {
        // SwiftData requires iOS 17+ or macOS 14+
        XCTAssert(true, "SwiftData not supported on this platform")
    }
}
#endif
