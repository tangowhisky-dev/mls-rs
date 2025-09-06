import XCTest
import Foundation

// Import the MLS bindings
// Note: You may need to adjust the import based on your project setup
// import mls_rs_uniffi

// For now, we'll use relative import to the generated bindings
// In a real project, you'd want to properly configure your module map

class MLSSwiftTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Any setup that needs to happen before each test
    }
    
    override func tearDown() {
        // Clean up after each test
        super.tearDown()
    }
    
    // MARK: - Basic Configuration Tests
    
    func testClientConfigDefault() throws {
        // Test that we can create a default client configuration
        let clientConfig = clientConfigDefault()
        XCTAssertNotNil(clientConfig, "Client config should not be nil")
    }
    
    func testGenerateSignatureKeypair() throws {
        // Test that we can generate a signature keypair
        let keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        XCTAssertNotNil(keypair, "Generated keypair should not be nil")
    }
    
    // MARK: - Client Creation Tests
    
    func testClientCreation() throws {
        let clientConfig = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let clientId = "alice".data(using: .utf8)!
        
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: clientConfig)
        XCTAssertNotNil(client, "Client should be created successfully")
        
        // Test signing identity
        let signingIdentity = try client.signingIdentity()
        XCTAssertNotNil(signingIdentity, "Signing identity should not be nil")
    }
    
    // MARK: - Group Creation Tests
    
    func testCreateGroup() throws {
        let clientConfig = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let clientId = "alice".data(using: .utf8)!
        
        let alice = Client(id: clientId, signatureKeypair: keypair, clientConfig: clientConfig)
        
        // Create a group with auto-generated ID
        let group = try alice.createGroup(groupId: nil)
        XCTAssertNotNil(group, "Group should be created successfully")
        
        // Write to storage to ensure persistence works
        try group.writeToStorage()
    }
    
    func testCreateGroupWithCustomId() throws {
        let clientConfig = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let clientId = "alice".data(using: .utf8)!
        
        let alice = Client(id: clientId, signatureKeypair: keypair, clientConfig: clientConfig)
        
        // Create a group with custom ID
        let groupId = "test-group-123".data(using: .utf8)!
        let group = try alice.createGroup(groupId: groupId)
        XCTAssertNotNil(group, "Group should be created successfully with custom ID")
        
        try group.writeToStorage()
    }
    
    // MARK: - Key Package Tests
    
    func testGenerateKeyPackageMessage() throws {
        let clientConfig = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let clientId = "bob".data(using: .utf8)!
        
        let bob = Client(id: clientId, signatureKeypair: keypair, clientConfig: clientConfig)
        
        let keyPackageMessage = try bob.generateKeyPackageMessage()
        XCTAssertNotNil(keyPackageMessage, "Key package message should be generated")
    }
    
    // MARK: - Group Membership Tests
    
    func testAddMemberToGroup() throws {
        let clientConfig = clientConfigDefault()
        
        // Create Alice
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let aliceId = "alice".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: clientConfig)
        
        // Create Bob
        let bobKeypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let bobId = "bob".data(using: .utf8)!
        let bob = Client(id: bobId, signatureKeypair: bobKeypair, clientConfig: clientConfig)
        
        // Alice creates a group
        let aliceGroup = try alice.createGroup(groupId: nil)
        
        // Bob generates a key package
        let bobKeyPackage = try bob.generateKeyPackageMessage()
        
        // Alice adds Bob to the group
        let commitResult = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])
        XCTAssertNotNil(commitResult.commitMessage, "Commit message should be generated")
        XCTAssertNotNil(commitResult.welcomeMessage, "Welcome message should be generated")
        
        // Alice processes her own commit
        let aliceProcessResult = try aliceGroup.processIncomingMessage(message: commitResult.commitMessage)
        XCTAssertNotNil(aliceProcessResult, "Alice should process commit successfully")
        
        // Bob joins the group using the welcome message
        let joinInfo = try bob.joinGroup(ratchetTree: nil, welcomeMessage: commitResult.welcomeMessage)
        let bobGroup = joinInfo.group
        XCTAssertNotNil(bobGroup, "Bob should join the group successfully")
        
        // Both parties write to storage
        try aliceGroup.writeToStorage()
        try bobGroup.writeToStorage()
    }
    
    // MARK: - Message Encryption Tests
    
    func testEncryptAndDecryptMessage() throws {
        let clientConfig = clientConfigDefault()
        
        // Create Alice
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let aliceId = "alice".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: clientConfig)
        
        // Create Bob
        let bobKeypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let bobId = "bob".data(using: .utf8)!
        let bob = Client(id: bobId, signatureKeypair: bobKeypair, clientConfig: clientConfig)
        
        // Set up the group with both members
        let aliceGroup = try alice.createGroup(groupId: nil)
        let bobKeyPackage = try bob.generateKeyPackageMessage()
        let commitResult = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])
        
        // Process the commit
        _ = try aliceGroup.processIncomingMessage(message: commitResult.commitMessage)
        let joinInfo = try bob.joinGroup(ratchetTree: nil, welcomeMessage: commitResult.welcomeMessage)
        let bobGroup = joinInfo.group
        
        // Alice encrypts a message
        let plaintext = "Hello, Bob!".data(using: .utf8)!
        let encryptedMessage = try aliceGroup.encryptApplicationMessage(applicationData: plaintext)
        XCTAssertNotNil(encryptedMessage, "Message should be encrypted successfully")
        
        // Bob decrypts the message
        let decryptResult = try bobGroup.processIncomingMessage(message: encryptedMessage)
        
        switch decryptResult {
        case .applicationMessage(let data):
            XCTAssertEqual(data, plaintext, "Decrypted message should match original")
        default:
            XCTFail("Expected application message, got different message type")
        }
        
        // Write to storage
        try aliceGroup.writeToStorage()
        try bobGroup.writeToStorage()
    }
    
    // MARK: - Group Management Tests
    
    func testGroupProposalWorkflow() throws {
        let clientConfig = clientConfigDefault()
        
        // Create Alice
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let aliceId = "alice".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: clientConfig)
        
        // Create Bob
        let bobKeypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let bobId = "bob".data(using: .utf8)!
        let bob = Client(id: bobId, signatureKeypair: bobKeypair, clientConfig: clientConfig)
        
        // Set up group
        let aliceGroup = try alice.createGroup(groupId: nil)
        let bobKeyPackage = try bob.generateKeyPackageMessage()
        
        // Alice proposes to add Bob (instead of directly adding)
        let proposal = try aliceGroup.proposeAddMembers(keyPackages: [bobKeyPackage])
        XCTAssertNotNil(proposal, "Proposal should be created")
        
        // Alice can then commit the pending proposals
        let commitResult = try aliceGroup.commit(additionalData: Data())
        XCTAssertNotNil(commitResult.commitMessage, "Commit message should be generated")
        
        try aliceGroup.writeToStorage()
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidCipherSuite() throws {
        // Test with all available cipher suites to ensure they work
        let validCipherSuites: [CipherSuite] = [
            .curve25519Aes128,
            .p256Aes128,
            .curve25519Aes256,
            .p256Aes256,
            .curve25519Chacha20Poly1305,
            .p384Aes256,
            .p521Aes256,
            .curve448Aes256,
            .curve448Chacha20Poly1305
        ]
        
        for cipherSuite in validCipherSuites {
            do {
                let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
                XCTAssertNotNil(keypair, "Should generate keypair for cipher suite \\(cipherSuite)")
            } catch {
                XCTFail("Failed to generate keypair for cipher suite \\(cipherSuite): \\(error)")
            }
        }
    }
    
    // MARK: - Storage and Persistence Tests
    
    func testGroupPersistence() throws {
        let clientConfig = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let clientId = "alice".data(using: .utf8)!
        let groupId = "persistent-group".data(using: .utf8)!
        
        let alice = Client(id: clientId, signatureKeypair: keypair, clientConfig: clientConfig)
        
        // Create and save group
        let group = try alice.createGroup(groupId: groupId)
        try group.writeToStorage()
        
        // Load the group back
        let loadedGroup = try alice.loadGroup(groupId: groupId)
        XCTAssertNotNil(loadedGroup, "Group should be loaded from storage")
        
        // Verify we can still use the loaded group
        try loadedGroup.writeToStorage()
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceGroupCreation() throws {
        let clientConfig = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let clientId = "alice".data(using: .utf8)!
        
        let alice = Client(id: clientId, signatureKeypair: keypair, clientConfig: clientConfig)
        
        measure {
            for i in 0..<10 {
                do {
                    let groupId = "perf-group-\\(i)".data(using: .utf8)!
                    let group = try alice.createGroup(groupId: groupId)
                    try group.writeToStorage()
                } catch {
                    XCTFail("Performance test failed: \\(error)")
                }
            }
        }
    }
}

// MARK: - Test Extensions

extension MLSSwiftTests {
    
    /// Helper method to create a test client with a given name
    private func createTestClient(name: String, cipherSuite: CipherSuite = .curve25519Aes128) throws -> Client {
        let clientConfig = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = name.data(using: .utf8)!
        
        return Client(id: clientId, signatureKeypair: keypair, clientConfig: clientConfig)
    }
    
    /// Helper method to set up a two-member group
    private func createTwoMemberGroup() throws -> (alice: Client, bob: Client, aliceGroup: Group, bobGroup: Group) {
        let alice = try createTestClient(name: "alice")
        let bob = try createTestClient(name: "bob")
        
        let aliceGroup = try alice.createGroup(groupId: nil)
        let bobKeyPackage = try bob.generateKeyPackageMessage()
        let commitResult = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])
        
        _ = try aliceGroup.processIncomingMessage(message: commitResult.commitMessage)
        let joinInfo = try bob.joinGroup(ratchetTree: nil, welcomeMessage: commitResult.welcomeMessage)
        let bobGroup = joinInfo.group
        
        return (alice, bob, aliceGroup, bobGroup)
    }
}
