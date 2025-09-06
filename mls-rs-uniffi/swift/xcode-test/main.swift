import Foundation

// Global cipher suite configuration - will be set from command line
var selectedCipherSuite: CipherSuite = .curve25519Aes128  // Default

// Helper function to get cipher suite by ID
func getCipherSuiteById(_ id: Int) -> CipherSuite {
    switch id {
    case 1: return .curve25519Aes128
    case 2: return .p256Aes128
    case 3: return .curve25519Chacha
    case 4: return .curve448Aes256
    case 5: return .p521Aes256
    case 6: return .curve448Chacha
    case 7: return .p384Aes256
    default: return .curve25519Aes128
    }
}

// Helper function to get cipher suite name
func getCipherSuiteName(_ cipherSuite: CipherSuite) -> String {
    switch cipherSuite {
    case .curve25519Aes128: return "curve25519Aes128"
    case .p256Aes128: return "p256Aes128"
    case .curve25519Chacha: return "curve25519Chacha"
    case .curve448Aes256: return "curve448Aes256"
    case .p521Aes256: return "p521Aes256"
    case .curve448Chacha: return "curve448Chacha"
    case .p384Aes256: return "p384Aes256"
    }
}

// Helper extension for result validation
extension String {
    func repeating(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

func runTests() {
    // Parse command line arguments
    let cipherSuiteId = CommandLine.arguments.count > 1 ? Int(CommandLine.arguments[1]) ?? 1 : 1
    
    // Set global cipher suite selection
    selectedCipherSuite = getCipherSuiteById(cipherSuiteId)
    let cipherSuiteName = getCipherSuiteName(selectedCipherSuite)
    
    print("🧪 MLS Swift Bindings Test - Comprehensive Edition")
    print("==================================================")
    print("🎯 Running tests with cipher suite: \(cipherSuiteName) (ID: \(cipherSuiteId))")
    print("==================================================")
    
    var testsPassed = 0
    var testsTotal = 0
    
    // Test 1: Client Configuration
    testsTotal += 1
    print("\n1. Testing clientConfigDefault()...")
    _ = clientConfigDefault()
    print("   ✅ Client config created successfully")
    testsPassed += 1
    
    // Test 2: Signature keypair generation
    testsTotal += 1
    print("\n2. Testing generateSignatureKeypair() with \(cipherSuiteName)...")
    do {
        _ = try generateSignatureKeypair(cipherSuite: selectedCipherSuite)
        print("   ✅ Signature keypair generated successfully")
        testsPassed += 1
    } catch {
        print("   ❌ FAILED - \(error)")
        exit(1)
    }
    
    // Test 3: Client Tests
    testsTotal += 1
    print("\n3. Running Client Tests...")
    if testClientBasics(cipherSuite: selectedCipherSuite) && testClientWithDifferentCipherSuites(cipherSuite: selectedCipherSuite) && testClientIdentity(cipherSuite: selectedCipherSuite) {
        testsPassed += 1
        print("   ✅ All client tests passed")
    } else {
        print("   ❌ Client tests failed")
    }
    
    // Test 4: Group Tests
    testsTotal += 1
    print("\n4. Running Group Tests...")
    if testGroupCreation(cipherSuite: selectedCipherSuite) && testGroupMembership(cipherSuite: selectedCipherSuite) && testGroupProposals(cipherSuite: selectedCipherSuite) && testGroupPersistence(cipherSuite: selectedCipherSuite) {
        testsPassed += 1
        print("   ✅ All group tests passed")
    } else {
        print("   ❌ Group tests failed")
    }
    
    // Test 5: Encryption Tests
    testsTotal += 1
    print("\n5. Running Encryption Tests...")
    if testMessageEncryption(cipherSuite: selectedCipherSuite) && testBidirectionalMessaging(cipherSuite: selectedCipherSuite) && testMultipleMessages(cipherSuite: selectedCipherSuite) && testLargeMessage(cipherSuite: selectedCipherSuite) {
        testsPassed += 1
        print("   ✅ All encryption tests passed")
    } else {
        print("   ❌ Encryption tests failed")
    }
    
    // Test 6: Advanced API Tests  
    testsTotal += 1
    print("\n6. Running Advanced API Tests...")
    if testAdvancedAPIs(cipherSuite: selectedCipherSuite) {
        testsPassed += 1
        print("   ✅ All advanced API tests passed")
    } else {
        print("   ❌ Advanced API tests failed")
    }
    
    // Test 7: Error Handling & Storage Tests
    testsTotal += 1
    print("\n7. Running Error Handling & Storage Tests...")
    if testErrorHandlingAndStorage(cipherSuite: selectedCipherSuite) {
        testsPassed += 1
        print("   ✅ All error handling & storage tests passed")
    } else {
        print("   ❌ Error handling & storage tests failed")
    }
    
    // Test 8: GroupStateStorage API Tests
    testsTotal += 1
    print("\n8. Running GroupStateStorage API Tests...")
    if testGroupStateStorageAPIs(cipherSuite: selectedCipherSuite) && testExtensionAndMessageWrappers(cipherSuite: selectedCipherSuite) {
        testsPassed += 1
        print("   ✅ All GroupStateStorage API tests passed")
    } else {
        print("   ❌ GroupStateStorage API tests failed")
    }
    
    // Test 9: Comprehensive API Tests (Previously Missing!)
    testsTotal += 1
    print("\n9. Running Comprehensive API Tests...")
    if testAdvancedGroupOperations(cipherSuite: selectedCipherSuite) && testGroupPersistenceWithLoad(cipherSuite: selectedCipherSuite) && testReceivedMessageTypes(cipherSuite: selectedCipherSuite) && testSigningIdentityOperations(cipherSuite: selectedCipherSuite) {
        testsPassed += 1
        print("   ✅ All comprehensive API tests passed")
    } else {
        print("   ❌ Comprehensive API tests failed")
    }
    
    // Test 10: Additional Error Handling & Storage Tests
    testsTotal += 1
    print("\n10. Running Additional Error Handling & Storage Tests...")
    if testErrorHandling(cipherSuite: selectedCipherSuite) && testGroupStateStorageOperations(cipherSuite: selectedCipherSuite) && testCipherSuiteSupport(cipherSuite: selectedCipherSuite) && testMembershipOperations(cipherSuite: selectedCipherSuite) {
        testsPassed += 1
        print("   ✅ All additional tests passed")
    } else {
        print("   ❌ Additional tests failed")
    }
    
    // Test 11: Cipher Suite Analysis
    testsTotal += 1
    print("\n11. Running Cipher Suite Analysis...")
    if analyzeCipherSuiteSupport(cipherSuite: selectedCipherSuite) && testCipherSuiteConversion(cipherSuite: selectedCipherSuite) {
        testsPassed += 1
        print("   ✅ Cipher suite analysis completed")
    } else {
        print("   ❌ Cipher suite analysis failed")
    }
    
    // Test 12: P521Aes256 Cipher Suite
    testsTotal += 1
    print("\n12. Testing P521Aes256 Cipher Suite...")
    if testP521Aes256CipherSuite() && testP521VsCurve25519Comparison() && testP521EnterpriseScenario() {
        testsPassed += 1
        print("   ✅ All P521Aes256 tests passed")
    } else {
        print("   ❌ P521Aes256 tests failed")
    }
    
    // Test 13: All 7 Standard Cipher Suites
    testsTotal += 1
    print("\n13. Testing All 7 Standard MLS Cipher Suites...")
    if testAllCipherSuites() {
        testsPassed += 1
        print("   ✅ All 7 cipher suites work correctly")
    } else {
        print("   ❌ Some cipher suites failed")
    }
    
    // Test 14: Enterprise Cipher Suite Categories  
    testsTotal += 1
    print("\n14. Testing Enterprise Cipher Suite Categories...")
    if testEnterpriseStandardCipherSuites() && testMobileOptimizedCipherSuites() && testHighSecurityCipherSuites() {
        testsPassed += 1
        print("   ✅ All enterprise categories passed")
    } else {
        print("   ❌ Enterprise categories failed")
    }
    
    // Test 15: Cipher Suite Interoperability
    testsTotal += 1
    print("\n15. Testing Cipher Suite Interoperability...")
    if testCipherSuiteInteroperability() {
        testsPassed += 1
        print("   ✅ Cipher suite interoperability works")
    } else {
        print("   ❌ Cipher suite interoperability failed")
    }
    
    // Final results
    print("\n" + "=".repeating(50))
    print("TEST SUMMARY")
    print("=".repeating(50))
    print("Total tests: \(testsTotal)")
    print("Passed: \(testsPassed)")
    print("Failed: \(testsTotal - testsPassed)")
    
    if testsPassed == testsTotal {
        print("\n🎉 ALL TESTS PASSED!")
        print("MLS Swift bindings are working correctly!")
    } else {
        print("\n❌ SOME TESTS FAILED!")
        exit(1)
    }
}

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

// Main execution
runTests()
