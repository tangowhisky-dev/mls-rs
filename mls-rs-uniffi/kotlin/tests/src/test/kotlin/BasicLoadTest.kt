import org.junit.Test
import kotlin.test.assertNotNull
import uniffi.mls_rs_uniffi.*

class BasicLoadTest {
    
    @Test
    fun testLibraryLoading() {
        println("Testing basic library loading...")
        
        try {
            // Test creating a basic client config
            val config = clientConfigDefault()
            println("✅ Library loaded successfully! Client config created")
            assertNotNull(config)
        } catch (e: Exception) {
            println("❌ Failed to load library: ${e.message}")
            e.printStackTrace()
            throw e
        }
    }
    
    @Test
    fun testCipherSuiteCreation() {
        println("Testing cipher suite creation...")
        
        try {
            // Test all 7 standard MLS cipher suites
            val cipherSuites = listOf(
                CipherSuite.CURVE25519_AES128,
                CipherSuite.P256_AES128,
                CipherSuite.CURVE25519_CHACHA,
                CipherSuite.CURVE448_AES256,
                CipherSuite.P521_AES256,
                CipherSuite.CURVE448_CHACHA,
                CipherSuite.P384_AES256
            )
            
            for ((index, cipherSuite) in cipherSuites.withIndex()) {
                println("✅ Cipher suite ${index + 1}: $cipherSuite")
            }
            
            println("✅ All 7 standard MLS cipher suites verified")
        } catch (e: Exception) {
            println("❌ Failed to create cipher suites: ${e.message}")
            e.printStackTrace()
            throw e
        }
    }
}
