import Foundation

// MARK: - Advanced Group Operations Tests

func testAdvancedGroupOperations(cipherSuite: CipherSuite) -> Bool {
    print("Testing Advanced Group Operations...")
    
    do {
        let config = clientConfigDefault()
        
        // Set up clients
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let aliceId = "alice_advanced".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: config)
        
        let bobKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let bobId = "bob_advanced".data(using: .utf8)!
        let bob = Client(id: bobId, signatureKeypair: bobKeypair, clientConfig: config)
        
        let charlieKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let charlieId = "charlie_advanced".data(using: .utf8)!
        let charlie = Client(id: charlieId, signatureKeypair: charlieKeypair, clientConfig: config)
        
        // Create group and add Bob
        let aliceGroup = try alice.createGroup(groupId: Data?.none)
        let bobKeyPackage = try bob.generateKeyPackageMessage()
        let addBobResult = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])
        _ = try aliceGroup.processIncomingMessage(message: addBobResult.commitMessage)
        let bobJoinInfo = try bob.joinGroup(ratchetTree: nil as RatchetTree?, welcomeMessage: addBobResult.welcomeMessage!)
        let _ = bobJoinInfo.group
        print("✓ Initial group setup with Alice and Bob")
        
        // Test exportTree
        let ratchetTree = try aliceGroup.exportTree()
        print("✓ exportTree() works - exported ratchet tree with \(ratchetTree.bytes.count) bytes")
        
        // Test proposeRemoveMembers
        let bobIdentity = try bob.signingIdentity()
        let removeProposals = try aliceGroup.proposeRemoveMembers(signingIdentities: [bobIdentity])
        print("✓ proposeRemoveMembers() works - created \(removeProposals.count) proposal(s)")
        
        // Commit the removal proposals
        let removeCommitResult = try aliceGroup.commit()
        _ = try aliceGroup.processIncomingMessage(message: removeCommitResult.commitMessage)
        print("✓ Committed member removal proposal")
        
        // Test direct member removal (add Charlie first)
        let charlieKeyPackage = try charlie.generateKeyPackageMessage()
        let addCharlieResult = try aliceGroup.addMembers(keyPackages: [charlieKeyPackage])
        _ = try aliceGroup.processIncomingMessage(message: addCharlieResult.commitMessage)
        let charlieJoinInfo = try charlie.joinGroup(ratchetTree: nil, welcomeMessage: addCharlieResult.welcomeMessage!)
        let _ = charlieJoinInfo.group
        print("✓ Added Charlie to group")
        
        // Test removeMembers directly
        let charlieIdentity = try charlie.signingIdentity()
        let directRemoveResult = try aliceGroup.removeMembers(signingIdentities: [charlieIdentity])
        _ = try aliceGroup.processIncomingMessage(message: directRemoveResult.commitMessage)
        print("✓ removeMembers() works - directly removed Charlie")
        
        return true
        
    } catch {
        print("✗ Advanced group operations test failed: \(error)")
        return false
    }
}

func testGroupPersistenceWithLoad(cipherSuite: CipherSuite) -> Bool {
    print("Testing Group Persistence with Load...")
    
    do {
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = "test_load_persistence".data(using: .utf8)!
        
        let alice = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        
        // Create a group with a specific ID
        let customGroupId = "test_group_123".data(using: .utf8)!
        let originalGroup = try alice.createGroup(groupId: customGroupId)
        try originalGroup.writeToStorage()
        print("✓ Group created and saved with custom ID")
        
        // Load the group from storage using the known ID
        let loadedGroup = try alice.loadGroup(groupId: customGroupId)
        print("✓ Group loaded from storage using loadGroup()")
        
        // Verify the loaded group is functional by performing an operation
        let testKeyPackage = try alice.generateKeyPackageMessage()
        let proposals = try loadedGroup.proposeAddMembers(keyPackages: [testKeyPackage])
        print("✓ Loaded group is functional - can create proposals (\(proposals.count) proposal(s))")
        
        return true
        
    } catch {
        print("✗ Group persistence with load test failed: \(error)")
        return false
    }
}

func testReceivedMessageTypes(cipherSuite: CipherSuite) -> Bool {
    print("Testing ReceivedMessage Types...")
    
    do {
        let config = clientConfigDefault()
        
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let aliceId = "alice_message_types".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: config)
        
        let bobKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let bobId = "bob_message_types".data(using: .utf8)!
        let bob = Client(id: bobId, signatureKeypair: bobKeypair, clientConfig: config)
        
        // Set up group
        let aliceGroup = try alice.createGroup(groupId: Optional<Data>.none)
        let bobKeyPackage = try bob.generateKeyPackageMessage()
        let commitResult = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])
        
        // Process commit message - should return commit-related ReceivedMessage
        let aliceProcessResult = try aliceGroup.processIncomingMessage(message: commitResult.commitMessage)
        switch aliceProcessResult {
        case .applicationMessage(_, _):
            print("✗ Unexpected applicationMessage when processing commit")
            return false
        case .commit(_, _):
            print("✓ processIncomingMessage() with commit message works")
        case .receivedProposal(_, _):
            print("✓ processIncomingMessage() with commit message works (proposal)")
        case .groupInfo:
            print("✓ processIncomingMessage() with commit message works (groupInfo)")
        case .welcome:
            print("✓ processIncomingMessage() with commit message works (welcome)")
        case .keyPackage:
            print("✓ processIncomingMessage() with commit message works (keyPackage)")
        }
        print("✓ processIncomingMessage() with commit message works")
        
        // Join Bob and test application messages
        let joinInfo = try bob.joinGroup(ratchetTree: nil, welcomeMessage: commitResult.welcomeMessage!)
        let bobGroup = joinInfo.group
        
        // Test application message
        let testMessage = "Test message".data(using: .utf8)!
        let encryptedMessage = try aliceGroup.encryptApplicationMessage(message: testMessage)
        let decryptResult = try bobGroup.processIncomingMessage(message: encryptedMessage)
        
        switch decryptResult {
        case .applicationMessage(let sender, let data):
            if data == testMessage {
                print("✓ ReceivedMessage.applicationMessage works correctly")
                print("   Sender information captured: \(sender)")
                return true
            } else {
                print("✗ Application message data mismatch")
                return false
            }
        case .commit(_, _):
            print("✗ Unexpected commit when processing application message")
            return false
        case .receivedProposal(_, _):
            print("✗ Unexpected proposal when processing application message")
            return false
        case .groupInfo:
            print("✗ Unexpected groupInfo when processing application message")
            return false
        case .welcome:
            print("✗ Unexpected welcome when processing application message")
            return false
        case .keyPackage:
            print("✗ Unexpected keyPackage when processing application message")
            return false
        }
        
    } catch {
        print("✗ ReceivedMessage types test failed: \(error)")
        return false
    }
}

func testSigningIdentityOperations(cipherSuite: CipherSuite) -> Bool {
    print("Testing SigningIdentity Operations...")
    
    do {
        let config = clientConfigDefault()
        
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let aliceId = "alice_identity".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: config)
        
        let bobKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let bobId = "bob_identity".data(using: .utf8)!
        let bob = Client(id: bobId, signatureKeypair: bobKeypair, clientConfig: config)
        
        // Get signing identities
        let aliceIdentity1 = try alice.signingIdentity()
        let aliceIdentity2 = try alice.signingIdentity()
        let bobIdentity = try bob.signingIdentity()
        
        // Test equality
        if aliceIdentity1 == aliceIdentity2 {
            print("✓ SigningIdentity equality works - same client identities are equal")
        } else {
            print("✗ SigningIdentity equality failed - same client should have equal identities")
            return false
        }
        
        if aliceIdentity1 != bobIdentity {
            print("✓ SigningIdentity inequality works - different clients have different identities")
        } else {
            print("✗ SigningIdentity inequality failed - different clients should have different identities")
            return false
        }
        
        print("✓ SigningIdentity operations work correctly")
        return true
        
    } catch {
        print("✗ SigningIdentity operations test failed: \(error)")
        return false
    }
}

// MARK: - Error Handling & Storage Tests

func testErrorHandling(cipherSuite: CipherSuite) -> Bool {
    print("Testing Error Handling...")
    
    do {
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = "error_test_client".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        
        // Test 1: Try to load non-existent group
        do {
            let nonExistentGroupId = "non_existent_group".data(using: .utf8)!
            _ = try client.loadGroup(groupId: nonExistentGroupId)
            print("✗ Should have thrown error for non-existent group")
            return false
        } catch {
            print("✓ Correctly throws error for non-existent group: \(error)")
        }
        
        print("✓ Error handling tests passed")
        return true
        
    } catch {
        print("✗ Error handling test setup failed: \(error)")
        return false
    }
}

func testGroupStateStorageOperations(cipherSuite: CipherSuite) -> Bool {
    print("Testing GroupStateStorage Operations...")
    
    do {
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = "storage_test_client".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        
        // Create a group with custom ID for storage testing
        let groupId = "storage_test_group".data(using: .utf8)!
        let group = try client.createGroup(groupId: groupId)
        
        // Test writeToStorage
        try group.writeToStorage()
        print("✓ writeToStorage() works")
        
        // Test loading the group back
        let loadedGroup = try client.loadGroup(groupId: groupId)
        print("✓ Group successfully loaded from storage")
        
        // Test operations on loaded group
        let keyPackage = try client.generateKeyPackageMessage()
        let proposals = try loadedGroup.proposeAddMembers(keyPackages: [keyPackage])
        print("✓ Loaded group is functional - can create \(proposals.count) proposal(s)")
        
        return true
        
    } catch {
        print("✗ GroupStateStorage operations test failed: \(error)")
        return false
    }
}

func testCipherSuiteSupport(cipherSuite: CipherSuite) -> Bool {
    print("Testing CipherSuite Support...")
    
    do {
        let config = clientConfigDefault()
        
        // Test available cipher suite
        print("  Testing \(cipherSuite)...")
        
        // Generate keypair for this cipher suite
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = "cipher_test_\(cipherSuite)".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        
        // Create group and generate key package
        let _ = try client.createGroup(groupId: nil)
        let _ = try client.generateKeyPackageMessage()
        
        print("    ✓ \(cipherSuite) works - group and key package created")
        print("✓ Cipher suite support works correctly")
        return true
        
    } catch {
        print("✗ CipherSuite support test failed: \(error)")
        return false
    }
}

func testMembershipOperations(cipherSuite: CipherSuite) -> Bool {
    print("Testing Membership Operations...")
    
    do {
        let config = clientConfigDefault()
        
        // Set up multiple clients
        let clients = try (0..<4).map { i in
            let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
            let clientId = "member_\(i)".data(using: .utf8)!
            return Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        }
        
        let alice = clients[0]
        let bob = clients[1] 
        let charlie = clients[2]
        let david = clients[3]
        
        // Create group with Alice
        let group = try alice.createGroup(groupId: Optional<Data>.none)
        
        // Test adding multiple members at once
        let keyPackages = try [bob, charlie, david].map { try $0.generateKeyPackageMessage() }
        let addResult = try group.addMembers(keyPackages: keyPackages)
        _ = try group.processIncomingMessage(message: addResult.commitMessage)
        print("✓ Added multiple members successfully")
        
        // Verify welcome messages for all new members
        if let welcomeMessage = addResult.welcomeMessage {
            let _ = try bob.joinGroup(ratchetTree: nil, welcomeMessage: welcomeMessage)
            let _ = try charlie.joinGroup(ratchetTree: nil, welcomeMessage: welcomeMessage)  
            let _ = try david.joinGroup(ratchetTree: nil, welcomeMessage: welcomeMessage)
            print("✓ All members can join using welcome message")
            
            // Test member removal
            let bobIdentity = try bob.signingIdentity()
            let charlieIdentity = try charlie.signingIdentity()
            
            let removeResult = try group.removeMembers(signingIdentities: [bobIdentity, charlieIdentity])
            _ = try group.processIncomingMessage(message: removeResult.commitMessage)
            print("✓ Removed multiple members successfully")
        } else {
            print("✗ No welcome message generated")
            return false
        }
        
        return true
        
    } catch {
        print("✗ Membership operations test failed: \(error)")
        return false
    }
}
