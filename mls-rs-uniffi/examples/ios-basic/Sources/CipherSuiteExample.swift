// MLS-RS Swift Bindings: Cipher Suite Support Example
// This file demonstrates the 5 supported cipher suites

import Foundation

/// Example showing all supported cipher suites in MLS-RS Swift bindings
class CipherSuiteExample {
    
    /// All cipher suites supported by MLS-RS Swift bindings
    static let supportedCipherSuites: [(suite: String, description: String, securityLevel: String)] = [
        (
            suite: "curve25519Aes128", 
            description: "MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519 (Suite ID: 1)",
            securityLevel: "128-bit"
        ),
        (
            suite: "p256Aes128", 
            description: "MLS_128_DHKEMP256_AES128GCM_SHA256_P256 (Suite ID: 2)",
            securityLevel: "128-bit"
        ),
        (
            suite: "curve25519Chacha", 
            description: "MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519 (Suite ID: 3)",
            securityLevel: "128-bit"
        ),
        (
            suite: "p521Aes256", 
            description: "MLS_256_DHKEMP521_AES256GCM_SHA512_P521 (Suite ID: 5)",
            securityLevel: "256-bit"
        ),
        (
            suite: "p384Aes256", 
            description: "MLS_256_DHKEMP384_AES256GCM_SHA384_P384 (Suite ID: 7)",
            securityLevel: "256-bit"
        )
    ]
    
    /// Print information about all supported cipher suites
    static func printSupportedCipherSuites() {
        print("MLS-RS Swift Bindings - Supported Cipher Suites")
        print("=" * 50)
        print()
        
        for (index, info) in supportedCipherSuites.enumerated() {
            print("\(index + 1). \(info.suite)")
            print("   Description: \(info.description)")
            print("   Security Level: \(info.securityLevel)")
            print()
        }
        
        print("Total: \(supportedCipherSuites.count) cipher suites supported")
        print()
        print("RFC 9420 Compliance:")
        print("✅ Supports 5 out of 7 standard MLS cipher suites")
        print("❌ Suite 4 (Curve448+AES256) - Not supported (CryptoKit limitation)")
        print("❌ Suite 6 (Curve448+ChaCha20) - Not supported (CryptoKit limitation)")
    }
    
    /// Example usage patterns for each cipher suite
    static func showUsageExamples() {
        print("Usage Examples:")
        print("=" * 30)
        print()
        
        print("1. Basic keypair generation:")
        print("```swift")
        for info in supportedCipherSuites {
            print("let \(info.suite)Key = try generateSignatureKeypair(cipherSuite: .\(info.suite))")
        }
        print("```")
        print()
        
        print("2. Client creation with different cipher suites:")
        print("```swift")
        print("let clientConfig = clientConfigDefault()")
        print()
        for info in supportedCipherSuites {
            print("// \(info.description)")
            print("let \(info.suite)Keypair = try generateSignatureKeypair(cipherSuite: .\(info.suite))")
            print("let \(info.suite)Client = Client(")
            print("    id: \"\(info.suite)-client\".data(using: .utf8)!,")
            print("    signatureKeypair: \(info.suite)Keypair,")
            print("    clientConfig: clientConfig")
            print(")")
            print()
        }
        print("```")
    }
    
    /// Security recommendations for cipher suite selection
    static func showSecurityRecommendations() {
        print("Security Recommendations:")
        print("=" * 40)
        print()
        
        print("For most applications:")
        print("• curve25519Aes128 - Best performance, widely supported")
        print("• p256Aes128 - NIST compliance required")
        print()
        
        print("For high-security applications:")
        print("• p521Aes256 - Maximum security level")
        print("• p384Aes256 - Government/defense applications")
        print()
        
        print("For constrained environments:")
        print("• curve25519Chacha - Alternative to AES, good for low-power devices")
        print()
        
        print("Algorithm Details:")
        print("─" * 20)
        for info in supportedCipherSuites {
            print("• \(info.suite): \(info.securityLevel) security")
        }
    }
}

// Example usage
extension String {
    static func *(string: String, count: Int) -> String {
        return String(repeating: string, count: count)
    }
}

// Demonstration
func demonstrateCipherSuiteSupport() {
    CipherSuiteExample.printSupportedCipherSuites()
    CipherSuiteExample.showUsageExamples()
    CipherSuiteExample.showSecurityRecommendations()
}

// Uncomment to run the demonstration
// demonstrateCipherSuiteSupport()
