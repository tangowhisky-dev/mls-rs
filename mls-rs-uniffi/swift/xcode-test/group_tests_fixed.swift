import Foundation

func testGroupCreation() -> Bool {
    print("Testing Group Creation...")
    
    do {
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = "test_group_alice".data(using: .utf8)!
        
        let alice = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        
        // Test 1: Create group with auto-generated ID
        let group1 = try alice.createGroup(groupId: nil)
        print("✓ Group created with auto-generated ID")
        
        // Test 2: Create group with custom ID
        let customGroupId = "my_custom_group".data(using: .utf8)!
        let group2 = try alice.createGroup(groupId: customGroupId)
        print("✓ Group created with custom ID")
        
        // Test 3: Save both groups to storage
        try alice.writeGroupToStorage(group: group1)
        try alice.writeGroupToStorage(group: group2)
        print("✓ Groups written to storage")
        
        return true
    } catch {
        print("✗ Group creation test failed: \(error)")
        return false
    }
}

func testGroupMembership() -> Bool {
    print("Testing Group Membership Operations...")
    
    do {
        // Set up clients
        let config = clientConfigDefault()
        
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let aliceId = "alice_membership".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: config)
        
        let bobKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let bobId = "bob_membership".data(using: .utf8)!
        let bob = Client(id: bobId, signatureKeypair: bobKeypair, clientConfig: config)
        
        // Alice creates a group
        let aliceGroup = try alice.createGroup(groupId: nil)
        print("✓ Alice created group")
        
        // Bob generates a key package
        let bobKeyPackage = try bob.generateKeyPackageMessage()
        print("✓ Bob generated key package")
        
        // Alice adds Bob to the group
        let commitResult = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])
        print("✓ Alice added Bob to group")
        
        // Alice processes her own commit
        _ = try aliceGroup.processIncomingMessage(message: commitResult.commitMessage)
        print("✓ Alice processed commit")
        
        // Bob joins the group using the welcome message
        let joinInfo = try bob.joinGroup(ratchetTree: nil, welcomeMessage: commitResult.welcomeMessage!)
        let bobGroup = joinInfo.group
        print("✓ Bob joined group")
        
        // Save both groups
        try alice.writeGroupToStorage(group: aliceGroup)
        try bob.writeGroupToStorage(group: bobGroup)
        print("✓ Both groups saved to storage")
        
        return true
        
    } catch {
        print("✗ Group membership test failed: \(error)")
        return false
    }
}

func testGroupProposals() -> Bool {
    print("Testing Group Proposal Workflow...")
    
    do {
        // Set up clients
        let config = clientConfigDefault()
        
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let aliceId = "alice_proposal".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: config)
        
        let bobKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let bobId = "bob_proposal".data(using: .utf8)!
        let bob = Client(id: bobId, signatureKeypair: bobKeypair, clientConfig: config)
        
        // Alice creates a group
        let aliceGroup = try alice.createGroup(groupId: nil)
        let bobKeyPackage = try bob.generateKeyPackageMessage()
        
        // Alice proposes to add Bob (instead of directly adding)
        _ = try aliceGroup.proposeAddMembers(keyPackages: [bobKeyPackage])
        print("✓ Proposal created")
        
        // Alice can then commit the pending proposals
        _ = try aliceGroup.commit()
        print("✓ Proposals committed")
        
        // Save group after proposals
        try alice.writeGroupToStorage(group: aliceGroup)
        print("✓ Group saved after proposals")
        
        return true
        
    } catch {
        print("✗ Group proposal test failed: \(error)")
        return false
    }
}

func testGroupPersistence() -> Bool {
    print("Testing Group Persistence...")
    
    do {
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let clientId = "test_persistence".data(using: .utf8)!
        
        let alice = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        
        // Create and save a group
        let originalGroup = try alice.createGroup(groupId: nil)
        try alice.writeGroupToStorage(group: originalGroup)
        print("✓ Group created and saved")
        
        // Load the group from storage
        let groupId = originalGroup.groupId()
        let loadedGroup = try alice.loadGroup(groupId: groupId)
        print("✓ Group loaded from storage")
        
        // Verify the loaded group is functional by getting its ID
        let loadedGroupId = loadedGroup.groupId()
        if loadedGroupId == groupId {
            print("✓ Loaded group is functional")
            return true
        } else {
            print("✗ Loaded group ID mismatch")
            return false
        }
        
    } catch {
        print("✗ Group persistence test failed: \(error)")
        return false
    }
}
