import Foundation

// Test all 7 standard MLS cipher suites
func testAllCipherSuites() -> Bool {
    print("🔐 Testing All 7 Standard MLS Cipher Suites...")
    
    let allCipherSuites: [CipherSuite] = [
        .curve25519Aes128,  // ID: 1
        .p256Aes128,        // ID: 2  
        .curve25519Chacha,  // ID: 3
        .curve448Aes256,    // ID: 4
        .p521Aes256,        // ID: 5
        .curve448Chacha,    // ID: 6
        .p384Aes256         // ID: 7
    ]
    
    var successCount = 0
    
    for cipherSuite in allCipherSuites {
        print("  Testing \(cipherSuite)...")
        
        do {
            // Test key generation
            let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
            
            // Test client creation
            let config = clientConfigDefault()
            let clientId = "test_\(cipherSuite)".data(using: .utf8)!
            let client = Client(
                id: clientId,
                signatureKeypair: keypair,
                clientConfig: config
            )
            
            // Test group creation
            let groupId: Data? = nil
            let _ = try client.createGroup(groupId: groupId)
            
            // Test key package generation
            let _ = try client.generateKeyPackageMessage()
            
            // Verify cipher suite consistency
            if keypair.cipherSuite == cipherSuite {
                print("    ✅ \(cipherSuite) works correctly")
                successCount += 1
            } else {
                print("    ❌ \(cipherSuite) cipher suite mismatch")
                return false
            }
            
        } catch {
            print("    ❌ \(cipherSuite) failed: \(error)")
            return false
        }
    }
    
    print("✅ All \(successCount)/\(allCipherSuites.count) cipher suites work correctly!")
    return successCount == allCipherSuites.count
}

func testEnterpriseStandardCipherSuites() -> Bool {
    print("🏢 Testing Enterprise Standard Cipher Suites...")
    
    // Most important enterprise cipher suites
    let enterpriseSuites: [CipherSuite] = [
        .p256Aes128,    // Most widely used enterprise standard
        .p384Aes256,    // Government/high-security standard  
        .p521Aes256     // Maximum security enterprise
    ]
    
    for suite in enterpriseSuites {
        do {
            let keypair = try generateSignatureKeypair(cipherSuite: suite)
            let config = clientConfigDefault()
            let client = Client(
                id: "enterprise_\(suite)".data(using: .utf8)!,
                signatureKeypair: keypair,
                clientConfig: config
            )
            let groupId: Data? = nil
            let _ = try client.createGroup(groupId: groupId)
            print("  ✅ Enterprise cipher suite \(suite) works")
        } catch {
            print("  ❌ Enterprise cipher suite \(suite) failed: \(error)")
            return false
        }
    }
    
    print("✅ All enterprise cipher suites work correctly")
    return true
}

func testMobileOptimizedCipherSuites() -> Bool {
    print("📱 Testing Mobile Optimized Cipher Suites...")
    
    // ChaCha20Poly1305 cipher suites are better for mobile/embedded
    let mobileSuites: [CipherSuite] = [
        .curve25519Chacha,  // Mobile standard
        .curve448Chacha     // High security mobile
    ]
    
    for suite in mobileSuites {
        do {
            let keypair = try generateSignatureKeypair(cipherSuite: suite)
            let config = clientConfigDefault()
            let client = Client(
                id: "mobile_\(suite)".data(using: .utf8)!,
                signatureKeypair: keypair,
                clientConfig: config
            )
            let groupId: Data? = nil
            let _ = try client.createGroup(groupId: groupId)
            print("  ✅ Mobile cipher suite \(suite) works")
        } catch {
            print("  ❌ Mobile cipher suite \(suite) failed: \(error)")
            return false
        }
    }
    
    print("✅ All mobile cipher suites work correctly")
    return true
}

func testHighSecurityCipherSuites() -> Bool {
    print("🔒 Testing High Security Cipher Suites...")
    
    // 256-bit security level cipher suites
    let highSecuritySuites: [CipherSuite] = [
        .curve448Aes256,    // X448 + AES-256
        .p521Aes256,        // P-521 + AES-256
        .curve448Chacha,    // X448 + ChaCha20
        .p384Aes256         // P-384 + AES-256
    ]
    
    for suite in highSecuritySuites {
        do {
            let keypair = try generateSignatureKeypair(cipherSuite: suite)
            let config = clientConfigDefault()
            let client = Client(
                id: "security_\(suite)".data(using: .utf8)!,
                signatureKeypair: keypair,
                clientConfig: config
            )
            let groupId: Data? = nil
            let _ = try client.createGroup(groupId: groupId)
            print("  ✅ High security cipher suite \(suite) works")
        } catch {
            print("  ❌ High security cipher suite \(suite) failed: \(error)")
            return false
        }
    }
    
    print("✅ All high security cipher suites work correctly")
    return true
}

func testCipherSuiteInteroperability() -> Bool {
    print("🔗 Testing Cipher Suite Interoperability...")
    
    // Test that different cipher suites can coexist
    let config = clientConfigDefault()
    
    do {
        // Create clients with different cipher suites
        let curve25519Keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let p256Keypair = try generateSignatureKeypair(cipherSuite: .p256Aes128)
        let p384Keypair = try generateSignatureKeypair(cipherSuite: .p384Aes256)
        
        let curve25519Client = Client(
            id: "curve25519_client".data(using: .utf8)!,
            signatureKeypair: curve25519Keypair,
            clientConfig: config
        )
        
        let p256Client = Client(
            id: "p256_client".data(using: .utf8)!,
            signatureKeypair: p256Keypair,
            clientConfig: config
        )
        
        let p384Client = Client(
            id: "p384_client".data(using: .utf8)!,
            signatureKeypair: p384Keypair,
            clientConfig: config
        )
        
        // Verify they can all generate key packages
        let groupId: Data? = nil
        let _ = try curve25519Client.createGroup(groupId: groupId)
        let _ = try p256Client.createGroup(groupId: groupId)
        let _ = try p384Client.createGroup(groupId: groupId)
        
        print("✅ Cipher suite interoperability test passed")
        return true
        
    } catch {
        print("❌ Cipher suite interoperability test failed: \(error)")
        return false
    }
}

// Legacy P521-specific tests (kept for backward compatibility)
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
