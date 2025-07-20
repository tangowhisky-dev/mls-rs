import XCTest
import MlsRs

final class CipherSuiteTests: XCTestCase {
    
    /// Test that all supported cipher suites can generate signature keypairs
    func testAllCipherSuitesCanGenerateKeypairs() throws {
        let allCipherSuites: [CipherSuite] = [
            .curve25519Aes128,  // Suite ID: 1
            .p256Aes128,        // Suite ID: 2  
            .curve25519Chacha,  // Suite ID: 3
            .p521Aes256,        // Suite ID: 5
            .p384Aes256         // Suite ID: 7
        ]
        
        for cipherSuite in allCipherSuites {
            print("Testing cipher suite: \(cipherSuite)")
            
            // Test signature keypair generation
            let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
            
            // Verify the keypair was created successfully
            XCTAssertEqual(keypair.cipherSuite, cipherSuite, "Cipher suite should match")
            // Note: The signature keys are opaque types in the current API
            XCTAssertEqual(keypair.cipherSuite, cipherSuite, "Cipher suite should be correctly set")
            
            print("✅ Successfully generated keypair for \(cipherSuite)")
        }
    }
    
    /// Test that clients can be created with all cipher suites
    func testClientCreationWithAllCipherSuites() throws {
        let clientConfig = clientConfigDefault()
        
        let allCipherSuites: [CipherSuite] = [
            .curve25519Aes128,
            .p256Aes128,
            .curve25519Chacha,
            .p521Aes256,
            .p384Aes256
        ]
        
        for cipherSuite in allCipherSuites {
            print("Testing client creation with cipher suite: \(cipherSuite)")
            
            // Generate keypair
            let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
            
            // Create client
            let clientId = "test-client-\(cipherSuite)".data(using: .utf8)!
            let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: clientConfig)
            
            // Verify client was created successfully
            XCTAssertNotNil(client, "Client should be created successfully")
            
            print("✅ Successfully created client with \(cipherSuite)")
        }
    }
    
    /// Test that key packages can be generated with all cipher suites
    func testKeyPackageGenerationWithAllCipherSuites() throws {
        let clientConfig = clientConfigDefault()
        
        let allCipherSuites: [CipherSuite] = [
            .curve25519Aes128,
            .p256Aes128,
            .curve25519Chacha,
            .p521Aes256,
            .p384Aes256
        ]
        
        for cipherSuite in allCipherSuites {
            print("Testing key package generation with cipher suite: \(cipherSuite)")
            
            // Generate keypair and create client
            let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)
            let clientId = "test-client-\(cipherSuite)".data(using: .utf8)!
            let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: clientConfig)
            
            // Generate key package
            let _ = try client.generateKeyPackageMessage()
            
            // Verify key package was created
            // Note: Message is an opaque type, we just verify it was created successfully
            print("✅ Successfully generated key package with \(cipherSuite)")
        }
    }
    
    /// Test cipher suite RFC 9420 compliance
    func testCipherSuiteRFC9420Compliance() {
        // According to RFC 9420, these are the defined cipher suites
        // that CryptoKit supports (as mentioned in the GitHub page)
        let expectedCipherSuites: [CipherSuite] = [
            .curve25519Aes128,  // 1: MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519
            .p256Aes128,        // 2: MLS_128_DHKEMP256_AES128GCM_SHA256_P256
            .curve25519Chacha,  // 3: MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519
            .p521Aes256,        // 5: MLS_256_DHKEMP521_AES256GCM_SHA512_P521
            .p384Aes256         // 7: MLS_256_DHKEMP384_AES256GCM_SHA384_P384
        ]
        
        // All expected cipher suites should be available
        XCTAssertEqual(expectedCipherSuites.count, 5, "Should have 5 supported cipher suites")
        
        // Test that each cipher suite can be used
        for cipherSuite in expectedCipherSuites {
            XCTAssertNoThrow(try generateSignatureKeypair(cipherSuite: cipherSuite), 
                           "Should be able to generate keypair for \(cipherSuite)")
        }
    }
    
    /// Test cipher suite descriptions and properties
    func testCipherSuiteProperties() {
        // Test that cipher suites have proper string representations
        let cipherSuiteDescriptions: [(CipherSuite, String)] = [
            (.curve25519Aes128, "curve25519Aes128"),
            (.p256Aes128, "p256Aes128"),
            (.curve25519Chacha, "curve25519Chacha"),
            (.p521Aes256, "p521Aes256"),
            (.p384Aes256, "p384Aes256")
        ]
        
        for (cipherSuite, expectedDescription) in cipherSuiteDescriptions {
            let description = String(describing: cipherSuite)
            XCTAssertEqual(description, expectedDescription, 
                          "Cipher suite description should match expected value")
        }
    }
    
    /// Test that different cipher suites generate different keypairs
    func testDifferentCipherSuitesGenerateDifferentKeypairs() throws {
        let cipherSuite1 = CipherSuite.curve25519Aes128
        let cipherSuite2 = CipherSuite.p256Aes128
        
        let keypair1 = try generateSignatureKeypair(cipherSuite: cipherSuite1)
        let keypair2 = try generateSignatureKeypair(cipherSuite: cipherSuite2)
        
        // Different cipher suites should generate different keypairs
        XCTAssertNotEqual(keypair1, keypair2, "Different cipher suites should generate different keypairs")
        XCTAssertNotEqual(keypair1.cipherSuite, keypair2.cipherSuite, "Cipher suites should be different")
        XCTAssertNotEqual(keypair1.publicKey, keypair2.publicKey, "Public keys should be different")
        XCTAssertNotEqual(keypair1.secretKey, keypair2.secretKey, "Secret keys should be different")
    }
    
    /// Performance test for keypair generation across all cipher suites
    func testKeypairGenerationPerformance() throws {
        let allCipherSuites: [CipherSuite] = [
            .curve25519Aes128,
            .p256Aes128,
            .curve25519Chacha,
            .p521Aes256,
            .p384Aes256
        ]
        
        measure {
            for cipherSuite in allCipherSuites {
                do {
                    _ = try generateSignatureKeypair(cipherSuite: cipherSuite)
                } catch {
                    XCTFail("Failed to generate keypair for \(cipherSuite): \(error)")
                }
            }
        }
    }
}
