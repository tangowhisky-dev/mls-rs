import Foundation

// MARK: - Cipher Suite Analysis

func analyzeCipherSuiteSupport() -> Bool {
    print("🔍 Analyzing Cipher Suite Support")
    print("=====================================")
    
    // Test the only available cipher suite in Swift bindings
    print("\n📱 SWIFT BINDINGS CIPHER SUITES:")
    print("Available cipher suites in generated Swift bindings:")
    print("1. ✅ CipherSuite.curve25519Aes128")
    
    do {
        // Test that this cipher suite actually works
        let config = clientConfigDefault()
        let keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let clientId = "cipher_test".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
        
        // Create a group to verify it works
        let groupId: Data? = nil
        let _ = try client.createGroup(groupId: groupId)
        let _ = try client.generateKeyPackageMessage()
        
        print("   ✅ Successfully tested CipherSuite.curve25519Aes128")
        print("   ✅ Group creation: OK")
        print("   ✅ Key package generation: OK")
        
    } catch {
        print("   ❌ Error testing cipher suite: \(error)")
        return false
    }
    
    print("\n🦀 RUST CRATE CIPHER SUITES:")
    print("Available cipher suites in original Rust mls-rs-core:")
    print("1. ✅ CipherSuite::CURVE25519_AES128 (ID: 1) - MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519")
    print("2. ✅ CipherSuite::P256_AES128 (ID: 2) - MLS_128_DHKEMP256_AES128GCM_SHA256_P256") 
    print("3. ✅ CipherSuite::CURVE25519_CHACHA (ID: 3) - MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519")
    print("4. ✅ CipherSuite::CURVE448_AES256 (ID: 4) - MLS_256_DHKEMX448_AES256GCM_SHA512_Ed448")
    print("5. ✅ CipherSuite::P521_AES256 (ID: 5) - MLS_256_DHKEMP521_AES256GCM_SHA512_P521")
    print("6. ✅ CipherSuite::CURVE448_CHACHA (ID: 6) - MLS_256_DHKEMX448_CHACHA20POLY1305_SHA512_Ed448") 
    print("7. ✅ CipherSuite::P384_AES256 (ID: 7) - MLS_256_DHKEMP384_AES256GCM_SHA384_P384")
    
    print("\n🔮 POST-QUANTUM CIPHER SUITES (feature = \"post-quantum\"):")
    print("8. ✅ CipherSuite::ML_KEM_512 (ID: 65001)")
    print("9. ✅ CipherSuite::ML_KEM_768 (ID: 65002)")
    print("10. ✅ CipherSuite::ML_KEM_1024 (ID: 65003)")
    print("11. ✅ CipherSuite::ML_KEM_768_X25519 (ID: 65100)")
    
    print("\n🔧 CRYPTO PROVIDER SUPPORT:")
    print("Different crypto providers support different subsets:")
    
    print("\n📚 OpenSSL Provider (default in UniFFI bindings):")
    print("   - Supports ALL 7 standard cipher suites (IDs 1-7)")
    print("   - Uses CipherSuite::all() which returns Iterator<1..=7>")
    
    print("\n🦀 RustCrypto Provider:")
    print("   - CipherSuite::P256_AES128")
    print("   - CipherSuite::P384_AES256") 
    print("   - CipherSuite::CURVE25519_AES128")
    print("   - CipherSuite::CURVE25519_CHACHA")
    
    print("\n🔐 AWS-LC Provider:")
    print("   Classical cipher suites:")
    print("   - CipherSuite::CURVE25519_AES128")
    print("   - CipherSuite::CURVE25519_CHACHA")
    print("   - CipherSuite::P256_AES128")
    print("   - CipherSuite::P384_AES256")
    print("   - CipherSuite::P521_AES256")
    print("   Post-quantum (with feature flag):")
    print("   - CipherSuite::ML_KEM_512")
    print("   - CipherSuite::ML_KEM_768")
    print("   - CipherSuite::ML_KEM_1024")
    print("   - CipherSuite::ML_KEM_768_X25519")
    
    print("\n🌐 WebCrypto Provider:")
    print("   - Limited subset for browser compatibility")
    
    print("\n🍎 CryptoKit Provider (macOS/iOS):")
    print("   - Apple platform-specific implementation")
    
    print("\n⚠️  LIMITATION ANALYSIS:")
    print("=====================================")
    print("❌ Swift bindings only expose 1 out of 7+ cipher suites")
    print("❌ Most production apps need P-256 (CipherSuite::P256_AES128)")
    print("❌ Enterprise apps often need P-384 (CipherSuite::P384_AES256)")
    print("❌ High-security apps need P-521 (CipherSuite::P521_AES256)")
    print("❌ Post-quantum readiness requires ML-KEM cipher suites")
    
    print("\n💡 RECOMMENDATIONS:")
    print("=====================================")
    print("1. 🎯 Add CipherSuite::P256_AES128 (most widely used)")
    print("2. 🎯 Add CipherSuite::P384_AES256 (enterprise standard)")
    print("3. 🎯 Add CipherSuite::P521_AES256 (high security)")
    print("4. 🔮 Consider post-quantum cipher suites for future-proofing")
    print("5. 🔧 The UniFFI binding at mls-rs-uniffi/src/lib.rs line 277-296")
    print("   needs to be expanded to include more cipher suite variants")
    
    print("\n📝 IMPLEMENTATION NOTE:")
    print("The limitation is in the UniFFI wrapper, not the underlying Rust library.")
    print("The Rust mls-rs library with OpenSSL provider supports all standard cipher suites.")
    print("To add more cipher suites, modify the CipherSuite enum in mls-rs-uniffi/src/lib.rs")
    
    return true
}

func testCipherSuiteConversion() -> Bool {
    print("\n🔄 Testing Cipher Suite Conversion...")
    
    do {
        // Test that our single cipher suite works end-to-end
        let config = clientConfigDefault()
        let keypair1 = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        let keypair2 = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
        
        let client1 = Client(id: "test1".data(using: .utf8)!, signatureKeypair: keypair1, clientConfig: config)
        let client2 = Client(id: "test2".data(using: .utf8)!, signatureKeypair: keypair2, clientConfig: config)
        
        // Create a group and test full workflow
        let groupId: Data? = nil
        let group = try client1.createGroup(groupId: groupId)
        let keyPackage = try client2.generateKeyPackageMessage()
        let addResult = try group.addMembers(keyPackages: [keyPackage])
        _ = try group.processIncomingMessage(message: addResult.commitMessage)
        
        if let welcomeMessage = addResult.welcomeMessage {
            let joinInfo = try client2.joinGroup(ratchetTree: nil as RatchetTree?, welcomeMessage: welcomeMessage)
            let _ = joinInfo.group
            print("   ✅ Full cipher suite workflow test passed")
            return true
        } else {
            print("   ❌ No welcome message generated")
            return false
        }
        
    } catch {
        print("   ❌ Cipher suite conversion test failed: \(error)")
        return false
    }
}
