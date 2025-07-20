import XCTest
@testable import MlsRs

final class MlsRsTests: XCTestCase {
    
    func testBasicMlsWorkflow() throws {
        // Get default client configuration
        let clientConfig = clientConfigDefault()
        
        // Generate signature keypairs for Alice and Bob
        let aliceKey = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        
        // Create clients
        let aliceId = "alice".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKey, clientConfig: clientConfig)
        
        // Alice creates a group
        let group = try alice.createGroup(groupId: nil)
        
        // Test message encryption
        let message = "Hello, MLS!".data(using: .utf8)!
        let encryptedMessage = try group.encryptApplicationMessage(message: message)
        XCTAssertNotNil(encryptedMessage)
        
        // Test storage write
        try group.writeToStorage()
        
        print("✅ Basic MLS workflow test completed successfully!")
    }
    
    func testCustomStorage() throws {
        // Custom in-memory storage for testing
        class TestStorage: GroupStateStorage {
            var storedData: [String: Data] = [:]
            var epochs: [String: [UInt64: Data]] = [:]
            var maxEpochs: [String: UInt64] = [:]
            
            func state(groupId: Data) throws -> Data? {
                let key = groupId.base64EncodedString()
                return storedData[key]
            }
            
            func epoch(groupId: Data, epochId: UInt64) throws -> Data? {
                let key = groupId.base64EncodedString()
                return epochs[key]?[epochId]
            }
            
            func write(groupId: Data, groupState: Data, epochInserts: [EpochRecord], epochUpdates: [EpochRecord]) throws {
                let key = groupId.base64EncodedString()
                storedData[key] = groupState
                
                if epochs[key] == nil {
                    epochs[key] = [:]
                }
                
                for epoch in epochInserts {
                    epochs[key]?[epoch.id] = epoch.data
                    let currentMax = maxEpochs[key] ?? 0
                    if epoch.id > currentMax {
                        maxEpochs[key] = epoch.id
                    }
                }
                
                for epoch in epochUpdates {
                    epochs[key]?[epoch.id] = epoch.data
                    let currentMax = maxEpochs[key] ?? 0
                    if epoch.id > currentMax {
                        maxEpochs[key] = epoch.id
                    }
                }
            }
            
            func maxEpochId(groupId: Data) throws -> UInt64? {
                let key = groupId.base64EncodedString()
                return maxEpochs[key]
            }
        }
        
        // Create storage and configuration
        let storage = TestStorage()
        let config = ClientConfig(groupStateStorage: storage, useRatchetTreeExtension: true)
        
        // Create client with custom storage
        let keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let clientId = "test_client".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        
        // Create group and test storage
        let group = try client.createGroup(groupId: nil)
        XCTAssertEqual(storage.storedData.count, 0) // Should be empty before writeToStorage
        
        try group.writeToStorage()
        XCTAssertEqual(storage.storedData.count, 1) // Should contain one group now
        
        // Test message encryption and storage update
        let message = "Test message".data(using: .utf8)!
        _ = try group.encryptApplicationMessage(message: message)
        
        try group.writeToStorage()
        XCTAssertEqual(storage.storedData.count, 1) // Still one group, but updated
        
        print("✅ Custom storage test completed successfully!")
    }
}
