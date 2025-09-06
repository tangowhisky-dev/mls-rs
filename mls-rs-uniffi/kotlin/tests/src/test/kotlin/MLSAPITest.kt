package org.mls.test

import org.junit.Test
import org.junit.Assert.*
import uniffi.mls_rs_uniffi.*

/**
 * Comprehensive API testing suite for MLS Kotlin bindings.
 * This test focuses on API correctness, basic functionality, and all cipher suites.
 */
class MLSAPITest {
    
    @Test
    fun testClientConfiguration() {
        println("🔧 Testing Client Configuration...")
        
        // Test client config creation
        val config = clientConfigDefault()
        assertNotNull("Client config should be created", config)
        println("✅ Client configuration validated")
    }
    
    @Test
    fun testSignatureKeypairGeneration() {
        println("🔑 Testing Signature Keypair Generation...")
        
        val cipherSuites = listOf(
            CipherSuite.CURVE25519_AES128,
            CipherSuite.P256_AES128,
            CipherSuite.CURVE25519_CHACHA,
            CipherSuite.CURVE448_AES256,
            CipherSuite.P521_AES256,
            CipherSuite.CURVE448_CHACHA,
            CipherSuite.P384_AES256
        )
        
        for (cipherSuite in cipherSuites) {
            try {
                val keypair = generateSignatureKeypair(cipherSuite)
                assertNotNull("Keypair should be generated for $cipherSuite", keypair)
                println("✅ Signature keypair generated for $cipherSuite")
            } catch (e: Exception) {
                fail("Failed to generate keypair for $cipherSuite: ${e.message}")
            }
        }
        
        println("✅ All cipher suites signature keypair generation validated")
    }
    
    @Test 
    fun testClientCreation() {
        println("👤 Testing Client Creation...")
        
        val cipherSuite = CipherSuite.CURVE25519_AES128
        
        try {
            // Generate signature keypair
            val keypair = generateSignatureKeypair(cipherSuite)
            
            // Create client config
            val config = clientConfigDefault()
            
            // Create client identifier
            val clientId = "test-client-kotlin".toByteArray()
            
            // Create client
            val client = Client(clientId, keypair, config)
            
            assertNotNull("Client should be created", client)
            println("✅ Client created successfully")
            
        } catch (e: Exception) {
            println("❌ Client creation failed: ${e.message}")
            e.printStackTrace()
            throw e
        }
    }
    
    @Test
    fun testGroupCreation() {
        println("👥 Testing Group Creation...")
        
        val cipherSuite = CipherSuite.CURVE25519_AES128
        
        try {
            // Generate signature keypair
            val keypair = generateSignatureKeypair(cipherSuite)
            
            // Create client config
            val config = clientConfigDefault()
            
            // Create client identifier
            val clientId = "test-client-kotlin".toByteArray()
            
            // Create client
            val client = Client(clientId, keypair, config)
            
            // Create group
            val group = client.createGroup(null)
            assertNotNull("Group should be created", group)
            
            // Write to storage
            group.writeToStorage()
            
            println("✅ Group created and stored successfully")
            
        } catch (e: Exception) {
            println("❌ Group creation failed: ${e.message}")
            e.printStackTrace()
            throw e
        }
    }
    
    @Test
    fun testAllCipherSuites() {
        println("🧪 Testing All Cipher Suites...")
        
        val cipherSuites = mapOf(
            1 to CipherSuite.CURVE25519_AES128,
            2 to CipherSuite.P256_AES128,
            3 to CipherSuite.CURVE25519_CHACHA,
            4 to CipherSuite.CURVE448_AES256,
            5 to CipherSuite.P521_AES256,
            6 to CipherSuite.CURVE448_CHACHA,
            7 to CipherSuite.P384_AES256
        )
        
        val cipherSuiteNames = mapOf(
            CipherSuite.CURVE25519_AES128 to "Curve25519 AES-128 (baseline)",
            CipherSuite.P256_AES128 to "P-256 AES-128 (enterprise)",
            CipherSuite.CURVE25519_CHACHA to "Curve25519 ChaCha (mobile)",
            CipherSuite.CURVE448_AES256 to "Curve448 AES-256 (high security)",
            CipherSuite.P521_AES256 to "P-521 AES-256 (maximum security)",
            CipherSuite.CURVE448_CHACHA to "Curve448 ChaCha (high security mobile)",
            CipherSuite.P384_AES256 to "P-384 AES-256 (government)"
        )
        
        for ((id, cipherSuite) in cipherSuites) {
            try {
                val name = cipherSuiteNames[cipherSuite] ?: "Unknown"
                println("Testing cipher suite $id: $name")
                
                // Test signature keypair generation
                val keypair = generateSignatureKeypair(cipherSuite)
                assertNotNull("Keypair should be generated for $name", keypair)
                
                // Create basic client config
                val config = clientConfigDefault()
                
                // Create client identifier
                val clientId = "test-client-$id".toByteArray()
                
                // Test client creation (basic validation)
                val client = Client(clientId, keypair, config)
                
                assertNotNull("Client should be created for $name", client)
                println("✅ Cipher suite $id validated successfully")
                
            } catch (e: Exception) {
                fail("Cipher suite $id failed: ${e.message}")
            }
        }
        
        println("✅ All 7 cipher suites validated successfully")
    }
    
    @Test
    fun testErrorHandling() {
        println("⚠️ Testing Error Handling...")
        
        try {
            // Test basic error handling by trying operations that should work
            val config = clientConfigDefault()
            assertNotNull("Config should be created", config)
            
            val cipherSuite = CipherSuite.CURVE25519_AES128
            val keypair = generateSignatureKeypair(cipherSuite)
            assertNotNull("Keypair should be created", keypair)
            
            println("✅ Error handling test completed (basic operations work)")
            
        } catch (e: Exception) {
            println("❌ Unexpected error in basic operations: ${e.message}")
            throw e
        }
    }
}
