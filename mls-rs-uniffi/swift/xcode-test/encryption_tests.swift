import Foundation

func testMessageEncryption(cipherSuite: CipherSuite) -> Bool {
    print("Testing Message Encryption and Decryption...")
    
    do {
        let config = clientConfigDefault()
        
        // Create Alice
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let aliceId = "enc_test_alice".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: config)
        
        // Create Bob
        let bobKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let bobId = "enc_test_bob".data(using: .utf8)!
        let bob = Client(id: bobId, signatureKeypair: bobKeypair, clientConfig: config)
        
        // Set up group with both members
        let aliceGroup = try alice.createGroup(groupId: nil)
        let bobKeyPackage = try bob.generateKeyPackageMessage()
        let commitResult = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])
        
        // Process commit and join
        _ = try aliceGroup.processIncomingMessage(message: commitResult.commitMessage)
        let joinInfo = try bob.joinGroup(ratchetTree: nil, welcomeMessage: commitResult.welcomeMessage!)
        let bobGroup = joinInfo.group
        
        print("✓ Two-member group established")
        
        // Test message encryption/decryption
        let testMessage = "Hello from Alice to Bob! 🎉".data(using: .utf8)!
        let encryptedMessage = try aliceGroup.encryptApplicationMessage(message: testMessage)
        print("✓ Message encrypted by Alice")
        
        let decryptResult = try bobGroup.processIncomingMessage(message: encryptedMessage)
        print("✓ Message processed by Bob")
        
        // Verify the decrypted message
        switch decryptResult {
        case .applicationMessage(_, let data):
            if data == testMessage {
                print("✓ Message decrypted correctly")
                let decryptedString = String(data: data, encoding: .utf8) ?? "Invalid UTF-8"
                print("   Message content: '\(decryptedString)'")
                return true
            } else {
                print("✗ Decrypted message doesn't match original")
                return false
            }
        default:
            print("✗ Expected application message, got different type")
            return false
        }
        
    } catch {
        print("✗ Message encryption test failed: (error)")
        return false
    }
}

func testBidirectionalMessaging(cipherSuite: CipherSuite) -> Bool {
    print("Testing Bidirectional Messaging...")
    
    do {
        let config = clientConfigDefault()
        
        // Create Alice
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let aliceId = "bidir_alice".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: config)
        
        // Create Bob
        let bobKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let bobId = "bidir_bob".data(using: .utf8)!
        let bob = Client(id: bobId, signatureKeypair: bobKeypair, clientConfig: config)
        
        // Set up group
        let aliceGroup = try alice.createGroup(groupId: nil)
        let bobKeyPackage = try bob.generateKeyPackageMessage()
        let commitResult = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])
        
        _ = try aliceGroup.processIncomingMessage(message: commitResult.commitMessage)
        let joinInfo = try bob.joinGroup(ratchetTree: nil, welcomeMessage: commitResult.welcomeMessage!)
        let bobGroup = joinInfo.group
        
        // Test Alice → Bob message
        let message1 = "Hello from Alice!".data(using: .utf8)!
        let encrypted1 = try aliceGroup.encryptApplicationMessage(message: message1)
        let _ = try bobGroup.processIncomingMessage(message: encrypted1)
        print("✓ Alice → Bob message successful")
        
        // Test Bob → Alice message
        let message2 = "Hello from Bob!".data(using: .utf8)!
        let encrypted2 = try bobGroup.encryptApplicationMessage(message: message2)
        let _ = try aliceGroup.processIncomingMessage(message: encrypted2)
        print("✓ Bob → Alice message successful")
        print("✓ Bidirectional messaging works correctly")
        
        return true
        
    } catch {
        print("✗ Bidirectional messaging test failed: \(error)")
        return false
    }
}

func testMultipleMessages(cipherSuite: CipherSuite) -> Bool {
    print("Testing Multiple Messages in Sequence...")
    
    do {
        let config = clientConfigDefault()
        
        // Create clients
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let aliceId = "multi_test_alice".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: config)
        
        let bobKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let bobId = "multi_test_bob".data(using: .utf8)!
        let bob = Client(id: bobId, signatureKeypair: bobKeypair, clientConfig: config)
        
        // Set up group
        let aliceGroup = try alice.createGroup(groupId: nil)
        let bobKeyPackage = try bob.generateKeyPackageMessage()
        let commitResult = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])
        
        _ = try aliceGroup.processIncomingMessage(message: commitResult.commitMessage)
        let joinInfo = try bob.joinGroup(ratchetTree: nil, welcomeMessage: commitResult.welcomeMessage!)
        let bobGroup = joinInfo.group
        
        // Send multiple messages
        let messageCount = 5
        for i in 1...messageCount {
            let message = "Message #\(i) from Alice".data(using: .utf8)!
            let encrypted = try aliceGroup.encryptApplicationMessage(message: message)
            let decryptResult = try bobGroup.processIncomingMessage(message: encrypted)
            
            switch decryptResult {
            case .applicationMessage(_, let data):
                if data == message {
                    print("✓ Message \(i)/\(messageCount) delivered correctly")
                } else {
                    print("✗ Message (i) content mismatch")
                    return false
                }
            default:
                print("✗ Message \(i) unexpected type")
                return false
            }
        }
        
        print("✓ All \(messageCount) messages delivered successfully")
        return true
        
    } catch {
        print("✗ Multiple messages test failed: \(error)")
        return false
    }
}

func testLargeMessage(cipherSuite: CipherSuite) -> Bool {
    print("Testing Large Message Encryption...")
    
    do {
        let config = clientConfigDefault()
        
        // Create clients
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let aliceId = "large_test_alice".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: config)
        
        let bobKeypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
        let bobId = "large_test_bob".data(using: .utf8)!
        let bob = Client(id: bobId, signatureKeypair: bobKeypair, clientConfig: config)
        
        // Set up group
        let aliceGroup = try alice.createGroup(groupId: nil)
        let bobKeyPackage = try bob.generateKeyPackageMessage()
        let commitResult = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])
        
        _ = try aliceGroup.processIncomingMessage(message: commitResult.commitMessage)
        let joinInfo = try bob.joinGroup(ratchetTree: nil, welcomeMessage: commitResult.welcomeMessage!)
        let bobGroup = joinInfo.group
        
        // Create a large message (10KB)
        let largeString = String(repeating: "A", count: 10240)
        let largeMessage = largeString.data(using: .utf8)!
        
        print("   Testing \(largeMessage.count) byte message...")
        
        let encrypted = try aliceGroup.encryptApplicationMessage(message: largeMessage)
        let decryptResult = try bobGroup.processIncomingMessage(message: encrypted)
        
        switch decryptResult {
        case .applicationMessage(_, let data):
            if data == largeMessage {
                print("✓ Large message (\(data.count) bytes) encrypted and decrypted correctly")
                return true
            } else {
                print("✗ Large message content mismatch")
                return false
            }
        default:
            print("✗ Large message unexpected type")
            return false
        }
        
    } catch {
        print("✗ Large message test failed: (error)")
        return false
    }
}
