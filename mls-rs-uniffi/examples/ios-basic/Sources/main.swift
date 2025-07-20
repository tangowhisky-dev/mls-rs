import Foundation
import MlsRs

struct MlsRsExample {
    static func main() {
        print("🔐 MLS-RS Swift Example")
        print("======================")
        
        do {
            try testAllCipherSuites()
            print("\n✅ All cipher suite tests completed successfully!")
            
            try runBasicMlsWorkflow()
            print("\n✅ MLS workflow completed successfully!")
        } catch {
            print("\n❌ Error: \(error)")
        }
    }
    
    static func testAllCipherSuites() throws {
        print("\n🧪 Testing All Supported Cipher Suites")
        print("=====================================")
        
        let allCipherSuites: [(CipherSuite, String)] = [
            (.curve25519Aes128, "Curve25519 + AES-128 (Suite ID: 1)"),
            (.p256Aes128, "P-256 + AES-128 (Suite ID: 2)"),
            (.curve25519Chacha, "Curve25519 + ChaCha20-Poly1305 (Suite ID: 3)"),
            (.p521Aes256, "P-521 + AES-256 (Suite ID: 5)"),
            (.p384Aes256, "P-384 + AES-256 (Suite ID: 7)")
        ]
        
        print("   📊 Found \(allCipherSuites.count) supported cipher suites")
        print("   📖 As documented in RFC 9420: https://www.rfc-editor.org/rfc/rfc9420.html#name-mls-cipher-suites")
        print("")
        
        for (cipherSuite, description) in allCipherSuites {
            print("   🔧 Testing \(description)...")
            
            // Test signature keypair generation
            let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
            
            // Verify the keypair was created successfully
            guard keypair.cipherSuite == cipherSuite else {
                throw MlsExampleError.cipherSuiteMismatch(expected: cipherSuite, actual: keypair.cipherSuite)
            }
            // Note: SignatureKeypair keys are opaque types in the current API
            print("      ✓ Keypair generation successful")
            
            // Test client creation
            let clientConfig = clientConfigDefault()
            let clientId = "test-\(cipherSuite)".data(using: .utf8)!
            let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: clientConfig)
            
            // Test key package generation
            let _ = try client.generateKeyPackageMessage()
            // Note: Message is an opaque type, successful creation means it worked
            
            print("      ✅ Keypair generation: Success")
            print("      ✅ Client creation: Success")
            print("      ✅ Key package generation: Success")
            print("")
        }
        
        print("   🎉 All \(allCipherSuites.count) cipher suites passed validation!")
        print("")
        print("   📋 Summary of Supported Cipher Suites:")
        for (_, description) in allCipherSuites {
            print("      • \(description)")
        }
    }
    
    static func runBasicMlsWorkflow() throws {
        print("\n1. Setting up MLS clients...")
        
        // Get default client configuration
        let clientConfig = clientConfigDefault()
        print("   📋 Got default client configuration")
        
        // Generate signature keypairs for Alice and Bob
        let aliceKey = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let bobKey = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        print("   🔑 Generated signature keypairs for Alice and Bob")
        
        // Create clients
        let alice = Client(
            id: Data("alice".utf8),
            signatureKeypair: aliceKey,
            clientConfig: clientConfig
        )
        print("   👩 Created Alice client")
        
        let bob = Client(
            id: Data("bob".utf8),
            signatureKeypair: bobKey,
            clientConfig: clientConfig
        )
        print("   👨 Created Bob client")
        
        print("\n2. Creating MLS group...")
        
        // Alice creates a group
        let aliceGroup = try alice.createGroup(groupId: nil)
        print("   👥 Alice created a new group")
        
        // Bob generates a key package message to join the group
        let keyPackageMessage = try bob.generateKeyPackageMessage()
        print("   📦 Bob generated key package message")
        
        print("\n3. Adding Bob to the group...")
        
        // Alice adds Bob to the group
        let commit = try aliceGroup.addMembers(keyPackages: [keyPackageMessage])
        print("   ➕ Alice generated commit to add Bob")
        
        // Alice processes her own commit
        let _ = try aliceGroup.processIncomingMessage(message: commit.commitMessage)
        print("   ✨ Alice processed her own commit")
        
        // Bob joins the group using the welcome message
        guard let welcomeMessage = commit.welcomeMessage else {
            throw MlsExampleError.invalidWorkflow("No welcome message generated")
        }
        let joinResult = try bob.joinGroup(
            ratchetTree: nil,
            welcomeMessage: welcomeMessage
        )
        let bobGroup = joinResult.group
        print("   👨‍💻 Bob joined the group successfully")
        
        print("\n4. Testing message encryption and decryption...")
        
        // Alice sends a message to the group
        let message = "Hello, Bob! This is a secure MLS message. 🔐"
        let messageData = Data(message.utf8)
        let encryptedMessage = try aliceGroup.encryptApplicationMessage(message: messageData)
        print("   📤 Alice encrypted message: '\(message)'")
        
        // Bob processes the incoming message
        let output = try bobGroup.processIncomingMessage(message: encryptedMessage)
        guard case .applicationMessage(_, let decryptedData) = output else {
            throw MlsExampleError.invalidWorkflow("Expected application message")
        }
        let decryptedMessage = String(data: decryptedData, encoding: .utf8) ?? ""
        print("   📥 Bob decrypted message: '\(decryptedMessage)'")
        
        // Verify the message was transmitted correctly
        guard decryptedMessage == message else {
            throw MlsExampleError.messageVerificationFailed(
                expected: message,
                received: decryptedMessage
            )
        }
        print("   ✅ Message integrity verified!")
        
        print("\n5. Testing Bob to Alice communication...")
        
        // Bob sends a reply
        let reply = "Hi Alice! MLS is working great! 🎉"
        let replyData = Data(reply.utf8)
        let encryptedReply = try bobGroup.encryptApplicationMessage(message: replyData)
        print("   📤 Bob encrypted reply: '\(reply)'")
        
        // Alice processes Bob's reply
        let replyOutput = try aliceGroup.processIncomingMessage(message: encryptedReply)
        guard case .applicationMessage(_, let decryptedReplyData) = replyOutput else {
            throw MlsExampleError.invalidWorkflow("Expected application message reply")
        }
        let decryptedReply = String(data: decryptedReplyData, encoding: .utf8) ?? ""
        print("   📥 Alice decrypted reply: '\(decryptedReply)'")
        
        // Verify the reply
        guard decryptedReply == reply else {
            throw MlsExampleError.messageVerificationFailed(
                expected: reply,
                received: decryptedReply
            )
        }
        print("   ✅ Reply integrity verified!")
        
        print("\n6. Persisting client state...")
        
        // Write group state to storage  
        try aliceGroup.writeToStorage()
        print("   💾 Alice's group state saved to storage")
        
        try bobGroup.writeToStorage()
        print("   💾 Bob's group state saved to storage")
        
        print("\n📊 MLS Session Summary:")
        print("   • Cipher Suite: CURVE25519_AES128")
        print("   • Participants: Alice, Bob")
        print("   • Messages Exchanged: 2")
        print("   • Encryption: End-to-End")
        print("   • Forward Secrecy: ✅")
        print("   • Post-Compromise Security: ✅")
    }
}

// MARK: - Error Types

enum MlsExampleError: Error, CustomStringConvertible {
    case messageVerificationFailed(expected: String, received: String)
    case cipherSuiteMismatch(expected: CipherSuite, actual: CipherSuite)
    case invalidKeypair(String)
    case invalidKeyPackage(String)
    case invalidWorkflow(String)
    
    var description: String {
        switch self {
        case .messageVerificationFailed(let expected, let received):
            return "Message verification failed. Expected: '\(expected)', Received: '\(received)'"
        case .cipherSuiteMismatch(let expected, let actual):
            return "Cipher suite mismatch. Expected: \(expected), Actual: \(actual)"
        case .invalidKeypair(let message):
            return "Invalid keypair: \(message)"
        case .invalidKeyPackage(let message):
            return "Invalid key package: \(message)"
        case .invalidWorkflow(let message):
            return "Invalid workflow: \(message)"
        }
    }
}

// MARK: - Async Version (when available)

#if ASYNC_SUPPORT
extension MlsRsExample {
    static func runBasicMlsWorkflowAsync() async throws {
        print("\n🔄 Running async MLS workflow...")
        
        // Get default client configuration
        let clientConfig = clientConfigDefault()
        
        // Generate signature keypairs for Alice and Bob
        let aliceKey = generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let bobKey = generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        
        // Create clients asynchronously
        var alice = try await Client(
            identity: Data("alice".utf8),
            signingKey: aliceKey,
            config: clientConfig
        )
        
        var bob = try await Client(
            identity: Data("bob".utf8),
            signingKey: bobKey,
            config: clientConfig
        )
        
        // Alice creates a group
        alice = try await alice.createGroup(externalPsk: nil)
        
        // Bob generates a key package message
        let keyPackageMessage = try await bob.generateKeyPackageMessage()
        
        // Alice adds Bob to the group
        let commit = try await alice.addMembers(keyPackages: [keyPackageMessage])
        
        // Process messages asynchronously
        try await alice.processIncomingMessage(message: commit.commitMessage)
        
        let joinResult = try await bob.joinGroup(
            externalPsk: nil,
            welcomeMessage: commit.welcomeMessage
        )
        bob = joinResult.group
        
        // Test async message encryption/decryption
        let messageData = Data("Async hello from Alice!".utf8)
        let encryptedMessage = try await alice.encryptApplicationMessage(data: messageData)
        let output = try await bob.processIncomingMessage(message: encryptedMessage)
        
        print("   📥 Async message received: '\(String(data: output.data, encoding: .utf8) ?? "")'")
        
        // Save state asynchronously
        try await alice.writeToStorage()
        try await bob.writeToStorage()
        
        print("   ✅ Async MLS workflow completed!")
    }
}
#endif

// Run the example
MlsRsExample.main()
