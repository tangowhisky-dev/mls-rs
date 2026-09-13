package com.mlsrs.testbed

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import uniffi.mls_rs_uniffi.CipherSuite
import uniffi.mls_rs_uniffi.Client
import uniffi.mls_rs_uniffi.Group
import uniffi.mls_rs_uniffi.ReceivedMessage
import uniffi.mls_rs_uniffi.SignatureKeypair
import uniffi.mls_rs_uniffi.SignaturePublicKey
import uniffi.mls_rs_uniffi.SignatureSecretKey
import uniffi.mls_rs_uniffi.clientConfigDefault
import uniffi.mls_rs_uniffi.generateSignatureKeypair

/**
 * On-device end-to-end scenarios for the RustCrypto-backed UniFFI library.
 * Mirrors platform_testbeds/android/e2e.kts; X.509 material is read from
 * androidTest assets populated by scripts/test_android.sh.
 */
@RunWith(AndroidJUnit4::class)
class E2ETest {

    private val allSuites = listOf(
        CipherSuite.CURVE25519_AES128,
        CipherSuite.P256_AES128,
        CipherSuite.CURVE25519_CHA_CHA,
        CipherSuite.P521_AES256,
        CipherSuite.P384_AES256,
    )

    private fun readAsset(vararg parts: String): ByteArray {
        val path = parts.joinToString("/")
        return InstrumentationRegistry.getInstrumentation().context.assets
            .open(path).use { it.readBytes() }
    }

    private fun groupScenario(alice: Client, bob: Client, label: String) {
        val aliceGroup: Group = alice.createGroup(null)
        val bobKeyPackage = bob.generateKeyPackageMessage()

        val commit = aliceGroup.addMembers(listOf(bobKeyPackage))
        aliceGroup.processIncomingMessage(commit.commitMessage)
        val bobGroup = bob.joinGroup(null, commit.welcomeMessage!!).group

        val encrypted = aliceGroup.encryptApplicationMessage("hello, bob".toByteArray())
        val received = bobGroup.processIncomingMessage(encrypted)
        assertTrue("$label: expected application message", received is ReceivedMessage.ApplicationMessage)
        assertEquals("hello, bob", (received as ReceivedMessage.ApplicationMessage).data.decodeToString())

        aliceGroup.writeToStorage()
        bobGroup.writeToStorage()
    }

    @Test
    fun testAllCipherSuites() {
        for (suite in allSuites) {
            val alice = Client("alice".toByteArray(), generateSignatureKeypair(suite), clientConfigDefault())
            val bob = Client("bob".toByteArray(), generateSignatureKeypair(suite), clientConfigDefault())
            groupScenario(alice, bob, suite.name)
        }
    }

    @Test
    fun testX509Identities() {
        val cases = listOf(
            Triple("ed25519", CipherSuite.CURVE25519_AES128, "x509-ed25519-suite1"),
            Triple("ed25519", CipherSuite.CURVE25519_CHA_CHA, "x509-ed25519-suite3"),
            Triple("p256", CipherSuite.P256_AES128, "x509-p256-suite2"),
            Triple("p384", CipherSuite.P384_AES256, "x509-p384-suite7"),
            Triple("p521", CipherSuite.P521_AES256, "x509-p521-suite5"),
        )

        for ((curve, suite, label) in cases) {
            val rootCa = readAsset("test_pki", "${curve}_ca", "cert.der")

            fun makeClient(who: String): Client {
                val cert = readAsset("test_pki", "${curve}_${who}", "cert.der")
                val keypair = SignatureKeypair(
                    suite,
                    SignaturePublicKey(readAsset("test_pki", "${curve}_${who}", "public.bin")),
                    SignatureSecretKey(readAsset("test_pki", "${curve}_${who}", "secret.bin")),
                )
                val config = clientConfigDefault().copy(rootCaCertificates = listOf(rootCa))
                return Client.newWithX509(listOf(cert), keypair, config)
            }

            groupScenario(makeClient("alice"), makeClient("bob"), label)
        }
    }
}
