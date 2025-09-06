import Foundation

// Helper extension for result validation
extension String {
    func repeating(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}

func runTests() {
    print("🧪 MLS Swift Bindings Test - Comprehensive Edition")
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
    print("\n2. Testing generateSignatureKeypair()...")
    do {
        _ = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        print("   ✅ Signature keypair generated successfully")
        testsPassed += 1
    } catch {
        print("   ❌ FAILED - \(error)")
        exit(1)
    }
    
    // Test 3: Client Tests
    testsTotal += 1
    print("\n3. Running Client Tests...")
    if testClientBasics() && testClientWithDifferentCipherSuites() && testClientIdentity() {
        testsPassed += 1
        print("   ✅ All client tests passed")
    } else {
        print("   ❌ Client tests failed")
    }
    
    // Test 4: Group Tests
    testsTotal += 1
    print("\n4. Running Group Tests...")
    if testGroupCreation() && testGroupMembership() && testGroupProposals() && testGroupPersistence() {
        testsPassed += 1
        print("   ✅ All group tests passed")
    } else {
        print("   ❌ Group tests failed")
    }
    
    // Test 5: Encryption Tests
    testsTotal += 1
    print("\n5. Running Encryption Tests...")
    if testMessageEncryption() && testBidirectionalMessaging() && testMultipleMessages() && testLargeMessage() {
        testsPassed += 1
        print("   ✅ All encryption tests passed")
    } else {
        print("   ❌ Encryption tests failed")
    }
    
    // Test 6: Advanced API Tests  
    testsTotal += 1
    print("\n6. Running Advanced API Tests...")
    if testAdvancedAPIs() {
        testsPassed += 1
        print("   ✅ All advanced API tests passed")
    } else {
        print("   ❌ Advanced API tests failed")
    }
    
    // Test 7: Error Handling & Storage Tests
    testsTotal += 1
    print("\n7. Running Error Handling & Storage Tests...")
    if testErrorHandlingAndStorage() {
        testsPassed += 1
        print("   ✅ All error handling & storage tests passed")
    } else {
        print("   ❌ Error handling & storage tests failed")
    }
    
    // Test 8: GroupStateStorage API Tests
    testsTotal += 1
    print("\n8. Running GroupStateStorage API Tests...")
    if testGroupStateStorageAPIs() && testExtensionAndMessageWrappers() {
        testsPassed += 1
        print("   ✅ All GroupStateStorage API tests passed")
    } else {
        print("   ❌ GroupStateStorage API tests failed")
    }
    
    // Test 9: Comprehensive API Tests (Previously Missing!)
    testsTotal += 1
    print("\n9. Running Comprehensive API Tests...")
    if testAdvancedGroupOperations() && testGroupPersistenceWithLoad() && testReceivedMessageTypes() && testSigningIdentityOperations() {
        testsPassed += 1
        print("   ✅ All comprehensive API tests passed")
    } else {
        print("   ❌ Comprehensive API tests failed")
    }
    
    // Test 10: Additional Error Handling & Storage Tests
    testsTotal += 1
    print("\n10. Running Additional Error Handling & Storage Tests...")
    if testErrorHandling() && testGroupStateStorageOperations() && testCipherSuiteSupport() && testMembershipOperations() {
        testsPassed += 1
        print("   ✅ All additional tests passed")
    } else {
        print("   ❌ Additional tests failed")
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

// Main execution
runTests()
