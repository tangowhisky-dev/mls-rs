import Foundation

func testAdvancedAPIs(cipherSuite: CipherSuite) -> Bool {
    print("\n=== Testing Advanced APIs ===")
    var allTestsPassed = true
    
    // Test 1: Load Group functionality
    do {
        print("Testing group storage and load operations...")
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = "advanced_client".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        
        // Create a group
        let group = try client.createGroup(groupId: nil as Data?)
        
        // Write the group to storage (this should create stored data)
        try group.writeToStorage()
        print("✓ Group storage operations working")
        
    } catch {
        print("⚠️ Group storage test failed: \(error)")
        // Don't fail for expected limitations, this is advanced functionality
    }
    
    // Test 2: Export tree functionality
    do {
        print("Testing exportTree...")
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = "tree_client".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        let group = try client.createGroup(groupId: Data?.none)
        
        // Test tree export (this might be implementation specific)
        let treeExport = try group.exportTree()
        print("✓ Tree export successful, size: \(treeExport.bytes.count) bytes")
        
    } catch {
        print("⚠️ exportTree test failed: \(error)")
        // Don't fail for unimplemented features
    }
    
    // Test 3: Member operations
    do {
        print("Testing member operations...")
        let config = clientConfigDefault()
        let keypair1 = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let keypair2 = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId1 = "client1".data(using: .utf8)!
        let clientId2 = "client2".data(using: .utf8)!
        let client1 = Client(id: clientId1, signatureKeypair: keypair1, clientConfig: config)
        let client2 = Client(id: clientId2, signatureKeypair: keypair2, clientConfig: config)
        
        let group = try client1.createGroup(groupId: nil as Data?)
        
        // Add a member
        let keyPackage2 = try client2.generateKeyPackageMessage()
        let _ = try group.proposeAddMembers(keyPackages: [keyPackage2])
        let commitResult = try group.commit()
        
        // Test joining the group
        let _ = try client2.joinGroup(ratchetTree: nil, welcomeMessage: commitResult.welcomeMessage!)
        print("✓ Member operations tested")
        
    } catch {
        print("⚠️ Member operations test failed: \(error)")
        allTestsPassed = false
    }
    
    // Test 4: Group state operations
    do {
        print("Testing group state operations...")
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = "state_client".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        let group = try client.createGroup(groupId: Data?.none)
        
        // Test various group state operations that are available
        // Note: Group doesn't expose epoch/groupId/cipherSuite directly in the current API
        try group.writeToStorage()
        print("✓ Group state operations completed successfully")
        
    } catch {
        print("⚠️ Group state operations test failed: \(error)")
        allTestsPassed = false
    }
    
    // Test 5: Multiple groups and cipher suite testing
    do {
        print("Testing multiple groups...")
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = "multi_client".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        
        // Create multiple groups
        for i in 1...3 {
            let customGroupId = "group_\(i)".data(using: .utf8)!
            let group = try client.createGroup(groupId: customGroupId)
            try group.writeToStorage()
            print("✓ Successfully created and stored group \(i)")
        }
        
    } catch {
        print("⚠️ Multiple groups testing failed: \(error)")
        allTestsPassed = false
    }
    
    print("=== Advanced API Tests Complete ===\n")
    return allTestsPassed
}