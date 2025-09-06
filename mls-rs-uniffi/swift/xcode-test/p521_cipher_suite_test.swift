import Foundation

// Test P521Aes256 cipher suite specifically
func testP521Aes256CipherSuite() -> Bool {
    print("🔐 Testing P521Aes256 Cipher Suite...")
    
    do {
        // Test 1: Key generation with P521Aes256
        print("  1. Testing key generation...")
        let p521Keypair = try generateSignatureKeypair(cipherSuite: .p521Aes256)
        print("    ✅ P521 key generation successful")
        
        // Test 2: Client creation with P521Aes256
        print("  2. Testing client creation...")
        let config = clientConfigDefault()
        let clientId = "p521_test_client".data(using: .utf8)!
        let client = Client(
            id: clientId,
            signatureKeypair: p521Keypair,
            clientConfig: config
        )
        print("    ✅ P521 client creation successful")
        
        // Test 3: Group creation with P521Aes256
        print("  3. Testing group creation...")
        let groupId = "p521_test_group".data(using: .utf8)
        let _ = try client.createGroup(groupId: groupId)
        print("    ✅ P521 group creation successful")
        
        // Test 4: Key package generation with P521Aes256
        print("  4. Testing key package generation...")
        let _ = try client.generateKeyPackageMessage()
        print("    ✅ P521 key package generation successful")
        
        // Test 5: Verify cipher suite consistency
        print("  5. Testing cipher suite consistency...")
        if p521Keypair.cipherSuite == .p521Aes256 {
            print("    ✅ P521 cipher suite consistency verified")
        } else {
            print("    ❌ P521 cipher suite mismatch")
            return false
        }
        
        print("✅ All P521Aes256 tests passed successfully!")
        return true
        
    } catch {
        print("❌ P521Aes256 test failed: \(error)")
        return false
    }
}

func testP521VsCurve25519Comparison() -> Bool {
    print("🔍 Testing P521 vs Curve25519 comparison...")
    
    do {
        // Generate keypairs for both cipher suites
        let p521Keypair = try generateSignatureKeypair(cipherSuite: .p521Aes256)
        let curve25519Keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        
        // Verify they have different cipher suites
        if p521Keypair.cipherSuite != curve25519Keypair.cipherSuite {
            print("  ✅ P521 and Curve25519 have different cipher suites as expected")
        } else {
            print("  ❌ P521 and Curve25519 cipher suites should be different")
            return false
        }
        
        // Verify specific cipher suite values
        if p521Keypair.cipherSuite == .p521Aes256 && 
           curve25519Keypair.cipherSuite == .curve25519Aes128 {
            print("  ✅ Cipher suite values are correct")
        } else {
            print("  ❌ Cipher suite values are incorrect")
            return false
        }
        
        // Test that both can create clients successfully
        let config = clientConfigDefault()
        
        let p521Client = Client(
            id: "p521_client".data(using: .utf8)!,
            signatureKeypair: p521Keypair,
            clientConfig: config
        )
        
        let curve25519Client = Client(
            id: "curve25519_client".data(using: .utf8)!,
            signatureKeypair: curve25519Keypair,
            clientConfig: config
        )
        
        // Both should be able to create groups
        let groupId: Data? = nil
        let _ = try p521Client.createGroup(groupId: groupId)
        let _ = try curve25519Client.createGroup(groupId: groupId)
        
        print("✅ P521 vs Curve25519 comparison test passed!")
        return true
        
    } catch {
        print("❌ P521 vs Curve25519 comparison test failed: \(error)")
        return false
    }
}

func testP521EnterpriseScenario() -> Bool {
    print("🏢 Testing P521 Enterprise Scenario...")
    
    do {
        // Create multiple P521 clients (simulating enterprise deployment)
        let config = clientConfigDefault()
        var clients: [Client] = []
        
        for i in 1...3 {
            let keypair = try generateSignatureKeypair(cipherSuite: .p521Aes256)
            let clientId = "enterprise_user_\(i)".data(using: .utf8)!
            let client = Client(
                id: clientId,
                signatureKeypair: keypair,
                clientConfig: config
            )
            clients.append(client)
        }
        
        // First client creates a group
        let _ = try clients[0].createGroup(groupId: "enterprise_group".data(using: .utf8))
        print("  ✅ Enterprise group created with P521")
        
        // Generate key packages for other clients
        for i in 1..<clients.count {
            let _ = try clients[i].generateKeyPackageMessage()
        }
        print("  ✅ Enterprise key packages generated with P521")
        
        print("✅ P521 Enterprise scenario test passed!")
        return true
        
    } catch {
        print("❌ P521 Enterprise scenario test failed: \(error)")
        return false
    }
}
