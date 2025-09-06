import Foundation

func testClientBasics() -> Bool {
    print("Testing Client Creation and Basic Operations...")
    
    do {
        // Test 1: Client configuration
        let config = clientConfigDefault()
        print("✓ Client configuration created")
        
        // Test 2: Signature keypair generation
        let keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        print("✓ Signature keypair generated")
        
        // Test 3: Client creation
        let clientId = "test_client_alice".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        print("✓ Client created successfully")
        
        // Test 4: Signing identity
        _ = try client.signingIdentity()
        print("✓ Signing identity retrieved")
        
        // Test 5: Key package generation
        _ = try client.generateKeyPackageMessage()
        print("✓ Key package message generated")
        
        return true
    } catch {
        print("✗ Client test failed: \(error)")
        return false
    }
}

func testClientWithDifferentCipherSuites() -> Bool {
    print("Testing Client Creation with Different Cipher Suites...")
    
    let testCipherSuites: [CipherSuite] = [
        .curve25519Aes128
    ]
    
    let config = clientConfigDefault()
    
    for (index, cipherSuite) in testCipherSuites.enumerated() {
        do {
            let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
            let clientId = "test_client_\(index)".data(using: .utf8)!
            let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
            
            // Test that we can generate a key package with this cipher suite
            _ = try client.generateKeyPackageMessage()
            
            print("✓ Cipher suite \(index + 1)/\(testCipherSuites.count) works")
        } catch {
            print("✗ Cipher suite \(cipherSuite) failed: \(error)")
            return false
        }
    }
    
    print("✓ All cipher suites tested successfully")
    return true
}

func testClientIdentity() -> Bool {
    print("Testing Client Identity Operations...")
    
    do {
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        
        // Test with different client IDs
        let testIds = ["alice", "bob", "charlie", "test@example.com", "user123"]
        
        for testId in testIds {
            let clientId = testId.data(using: .utf8)!
            let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
            
            _ = try client.signingIdentity()
            print("✓ Identity created for '\(testId)'")
        }
        
        return true
    } catch {
        print("✗ Client identity test failed: \(error)")
        return false
    }
}
