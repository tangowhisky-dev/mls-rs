import Foundation

func testMessageEncryption() -> Bool {
    print("Testing Message Encryption and Decryption...")
    
    do {
        let config = clientConfigDefault()
        
        // Create Alice
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let aliceId = "enc_test_alice".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: config)
        
        // Create Bob
        let bobKeypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
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

func testBidirectionalMessaging() -> Bool {
    print("Testing Bidirectional Messaging...")
    
    do {
        let config = clientConfigDefault()
        
        // Create Alice and Bob
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let aliceId = "bidir_test_alice".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: config)
        
        let bobKeypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let bobId = "bidir_test_bob".data(using: .utf8)!
        let bob = Client(id: bobId, signatureKeypair: bobKeypair, clientConfig: config)
        
        // Set up group
        let aliceGroup = try alice.createGroup(groupId: nil)
        let bobKeyPackage = try bob.generateKeyPackageMessage()
        let commitResult = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])
        
        _ = try aliceGroup.processIncomingMessage(message: commitResult.commitMessage)
        let joinInfo = try bob.joinGroup(ratchetTree: nil, welcomeMessage: commitResult.welcomeMessage!)
        let bobGroup = joinInfo.group
        
        // Alice sends message to Bob
        let aliceMessage = "Hello Bob!".data(using: .utf8)!
        let aliceEncrypted = try aliceGroup.encryptApplicationMessage(message: aliceMessage)
        let bobDecryptResult = try bobGroup.processIncomingMessage(message: aliceEncrypted)
        
        switch bobDecryptResult {
        case .applicationMessage(_, let data):
            if data == aliceMessage {
                print("✓ Alice → Bob message successful")
            } else {
                print("✗ Alice → Bob message failed")
                return false
            }
        default:
            print("✗ Alice → Bob unexpected message type")
            return false
        }
        
        // Bob sends message to Alice
        let bobMessage = "Hello Alice!".data(using: .utf8)!
        let bobEncrypted = try bobGroup.encryptApplicationMessage(message: bobMessage)
        let aliceDecryptResult = try aliceGroup.processIncomingMessage(message: bobEncrypted)
        
        switch aliceDecryptResult {
        case .applicationMessage(_, let data):
            if data == bobMessage {
                print("✓ Bob → Alice message successful")
            } else {
                print("✗ Bob → Alice message failed")
                return false
            }
        default:
            print("✗ Bob → Alice unexpected message type")
            return false
        }
        
        print("✓ Bidirectional messaging works correctly")
        return true
        
    } catch {
        print("✗ Bidirectional messaging test failed: (error)")
        return false
    }
}

func testMultipleMessages() -> Bool {
    print("Testing Multiple Messages in Sequence...")
    
    do {
        let config = clientConfigDefault()
        
        // Create clients
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let aliceId = "multi_test_alice".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: config)
        
        let bobKeypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
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

func testLargeMessage() -> Bool {
    print("Testing Large Message Encryption...")
    
    do {
        let config = clientConfigDefault()
        
        // Create clients
        let aliceKeypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let aliceId = "large_test_alice".data(using: .utf8)!
        let alice = Client(id: aliceId, signatureKeypair: aliceKeypair, clientConfig: config)
        
        let bobKeypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
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
