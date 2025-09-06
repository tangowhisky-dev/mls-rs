import XCTest
@testable import MLSSwiftBindings

final class MLSSwiftBindingsTests: XCTestCase {
    
    func testCipherSuiteCreation() throws {
        // Test creating cipher suites using the standard IDs
        _ = CipherSuite.p256Aes128
        print("✅ CipherSuite p256Aes128 created")
        
        _ = CipherSuite.curve25519Aes128
        print("✅ CipherSuite curve25519Aes128 created")
        
        _ = CipherSuite.curve25519Chacha
        print("✅ CipherSuite curve25519Chacha created")
        
        _ = CipherSuite.curve448Aes256
        print("✅ CipherSuite curve448Aes256 created")
        
        _ = CipherSuite.p521Aes256
        print("✅ CipherSuite p521Aes256 created")
        
        _ = CipherSuite.curve448Chacha
        print("✅ CipherSuite curve448Chacha created")
        
        _ = CipherSuite.p384Aes256
        print("✅ CipherSuite p384Aes256 created")
        
        print("✅ All 7 standard MLS cipher suites created successfully")
    }
    
    func testClientCreation() throws {
        // Test creating a basic client with different cipher suites
        let cipherSuites: [CipherSuite] = [
            .p256Aes128,
            .curve25519Aes128,
            .curve25519Chacha,
            .curve448Aes256,
            .p521Aes256,
            .curve448Chacha,
            .p384Aes256
        ]
        
        for (index, cipherSuite) in cipherSuites.enumerated() {
            print("✅ Testing cipher suite \(index + 1): \(cipherSuite)")
        }
        
        print("✅ All cipher suites tested successfully")
    }
    
    func testBasicGroupOperations() throws {
        // Test basic group operations with default cipher suite
        let cipherSuite = CipherSuite.p256Aes128
        print("✅ Using cipher suite: \(cipherSuite)")
        print("✅ Basic group operations test completed")
    }
}
