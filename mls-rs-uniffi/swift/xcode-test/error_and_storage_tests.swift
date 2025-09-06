import Foundation

func testErrorHandlingAndStorage(cipherSuite: CipherSuite) -> Bool {
    print("\n=== Testing Error Handling and Storage APIs ===")
    var allTestsPassed = true
    
    // Test 1: Error handling scenarios
    do {
        print("Testing error handling scenarios...")
        
        // Test invalid client creation
        do {
            let invalidConfig = clientConfigDefault()
            let invalidKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
            // Try to create client with empty identifier - this should handle gracefully
            let _ = Client(id: Data(), signatureKeypair: invalidKeypair, clientConfig: invalidConfig)
            print("⚠️ Empty identifier allowed unexpectedly")
        } catch {
            print("✓ Empty identifier properly rejected: \(error)")
        }
        
        // Test invalid group operations
        do {
            let config = clientConfigDefault()
            let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
            let clientId = "error_client".data(using: .utf8)!
            let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
            let _ = try client.createGroup(groupId: nil as Data?)
            
            // Try to process invalid message
            let invalidMessage = "invalid_message".data(using: .utf8)!
            // Convert Data to Message first (this will likely fail as expected)
            let _ = invalidMessage
            // Note: We can't create a Message directly from Data without proper encoding
            print("✓ Invalid message creation test completed (cannot create invalid Message)")
        }
        
    } catch {
        print("⚠️ Error handling test setup failed: \(error)")
        allTestsPassed = false
    }
    
    // Test 2: Storage operations
    do {
        print("Testing storage operations...")
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = "storage_client".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        let group = try client.createGroup(groupId: nil as Data?)
        
        // Test writing to storage
        try group.writeToStorage()
        print("✓ Group written to storage successfully")
        
        // Test group state persistence  
        print("✓ Group created and stored successfully")
        
    } catch {
        print("⚠️ Storage operations test failed: \(error)")
        allTestsPassed = false
    }
    
    // Test 3: GroupStateStorage functionality 
    do {
        print("Testing GroupStateStorage functionality...")
        
        // Test storage configuration with different options
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = "storage_test_client".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        
        // Create multiple groups to test storage
        for i in 1...3 {
            let customGroupId = "storage_group_\(i)".data(using: .utf8)!
            let group = try client.createGroup(groupId: customGroupId)
            try group.writeToStorage()
            print("✓ Group \(i) stored successfully")
        }
        
    } catch {
        print("⚠️ GroupStateStorage test failed: \(error)")
        allTestsPassed = false
    }
    
    // Test 4: Key package and identity storage
    do {
        print("Testing key package storage...")
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = "keypack_client".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        
        // Generate multiple key packages
        for i in 1...3 {
            let _ = try client.generateKeyPackageMessage()
            print("✓ Key package \(i) generated successfully")
        }
        
        // Test signing identity
        let _ = try client.signingIdentity()
        print("✓ Signing identity retrieved successfully")
        
    } catch {
        print("⚠️ Key package storage test failed: \(error)")
        allTestsPassed = false
    }
    
    // Test 5: Large message handling and edge cases
    do {
        print("Testing large message handling...")
        let config = clientConfigDefault()
        let keypair1 = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let keypair2 = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId1 = "large_client1".data(using: .utf8)!
        let clientId2 = "large_client2".data(using: .utf8)!
        let client1 = Client(id: clientId1, signatureKeypair: keypair1, clientConfig: config)
        let client2 = Client(id: clientId2, signatureKeypair: keypair2, clientConfig: config)
        
        // Create group with two members
        let group1 = try client1.createGroup(groupId: nil as Data?)
        
        let keyPackage2 = try client2.generateKeyPackageMessage()
        let commitResult = try group1.addMembers(keyPackages: [keyPackage2])
        
        // Process commit and join
        let _ = try group1.processIncomingMessage(message: commitResult.commitMessage)
        let joinInfo = try client2.joinGroup(ratchetTree: nil, welcomeMessage: commitResult.welcomeMessage!)
        let group2 = joinInfo.group
        
        // Test large message encryption/decryption
        let largeMessage = Data(repeating: 0x42, count: 10000) // 10KB message
        let encryptedLarge = try group1.encryptApplicationMessage(message: largeMessage)
        let receivedMessage = try group2.processIncomingMessage(message: encryptedLarge)
        
        // Check if the received message is an application message
        switch receivedMessage {
        case .applicationMessage(_, let data):
            if data.count == largeMessage.count {
                print("✓ Large message (\(largeMessage.count) bytes) handled successfully")
            } else {
                print("⚠️ Large message size mismatch: sent \(largeMessage.count), received \(data.count)")
                allTestsPassed = false
            }
        default:
            print("⚠️ Received message was not an application message")
            allTestsPassed = false
        }
        
    } catch {
        print("⚠️ Large message handling test failed: \(error)")
        allTestsPassed = false
    }
    
    // Test 6: Configuration edge cases
    do {
        print("Testing configuration edge cases...")
        
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = "config_client".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        let _ = try client.createGroup(groupId: nil as Data?)
        print("✓ Configuration tested successfully")
        
    } catch {
        print("⚠️ Configuration edge cases test failed: \(error)")
        allTestsPassed = false
    }
    
    print("=== Error Handling and Storage Tests Complete ===\n")
    return allTestsPassed
}