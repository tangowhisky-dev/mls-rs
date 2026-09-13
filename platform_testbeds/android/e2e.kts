// Kotlin/JVM end-to-end scenario for the generated UniFFI bindings.
// Exercises all five RustCrypto cipher suites plus X.509 clients.
//
// Usage (via scripts/test_kotlin.sh):
//   kotlinc -classpath <jna.jar>:gen/kotlin -script android/e2e.kts

import uniffi.mls_rs_uniffi.*
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths

val testbedRoot: Path = System.getenv("MLS_TESTBED_ROOT")?.let { Paths.get(it) }
    ?: Paths.get("").toAbsolutePath()

fun readBytes(vararg parts: String): ByteArray =
    Files.readAllBytes(testbedRoot.resolve(Paths.get(parts[0], *parts.drop(1).toTypedArray())))

fun assertEq(actual: Any?, expected: Any?, label: String) {
    if (actual != expected) throw AssertionError("$label: expected <$expected> got <$actual>")
}

val allSuites = listOf(
    CipherSuite.CURVE25519_AES128,
    CipherSuite.P256_AES128,
    CipherSuite.CURVE25519_CHA_CHA,
    CipherSuite.P521_AES256,
    CipherSuite.P384_AES256,
)

var failures = 0
fun check(label: String, body: () -> Unit) {
    try {
        body()
        println("PASS $label")
    } catch (e: Throwable) {
        failures++
        println("FAIL $label: $e")
    }
}

fun groupScenario(alice: Client, bob: Client, label: String) {
    val aliceGroup = alice.createGroup(null)
    val bobKeyPackage = bob.generateKeyPackageMessage()

    val commit = aliceGroup.addMembers(listOf(bobKeyPackage))
    aliceGroup.processIncomingMessage(commit.commitMessage)
    val bobGroup = bob.joinGroup(null, commit.welcomeMessage!!).group

    val encrypted = aliceGroup.encryptApplicationMessage("hello, bob".toByteArray())
    when (val received = bobGroup.processIncomingMessage(encrypted)) {
        is ReceivedMessage.ApplicationMessage ->
            assertEq(received.data.decodeToString(), "hello, bob", label)
        else -> throw AssertionError("$label: expected application message")
    }

    aliceGroup.writeToStorage()
    bobGroup.writeToStorage()
}

// --- basic credentials, all five cipher suites ---
for (suite in allSuites) {
    check("basic e2e $suite") {
        val aliceKey = generateSignatureKeypair(suite)
        val alice = Client("alice".toByteArray(), aliceKey, clientConfigDefault())
        val bobKey = generateSignatureKeypair(suite)
        val bob = Client("bob".toByteArray(), bobKey, clientConfigDefault())
        groupScenario(alice, bob, "$suite")
    }
}

// --- X.509 credentials ---
val x509Cases = listOf(
    Triple("ed25519", CipherSuite.CURVE25519_AES128, "x509-ed25519-suite1"),
    Triple("ed25519", CipherSuite.CURVE25519_CHA_CHA, "x509-ed25519-suite3"),
    Triple("p256", CipherSuite.P256_AES128, "x509-p256-suite2"),
    Triple("p384", CipherSuite.P384_AES256, "x509-p384-suite7"),
    Triple("p521", CipherSuite.P521_AES256, "x509-p521-suite5"),
)

for ((curve, suite, label) in x509Cases) {
    check(label) {
        val rootCa = readBytes("test_pki", "${curve}_ca", "cert.der")

        fun makeClient(who: String): Client {
            val cert = readBytes("test_pki", "${curve}_$who", "cert.der")
            val keypair = SignatureKeypair(
                suite,
                SignaturePublicKey(readBytes("test_pki", "${curve}_$who", "public.bin")),
                SignatureSecretKey(readBytes("test_pki", "${curve}_$who", "secret.bin")),
            )
            val config = clientConfigDefault().copy(rootCaCertificates = listOf(rootCa))
            return Client.newWithX509(listOf(cert), keypair, config)
        }

        val alice = makeClient("alice")
        val bob = makeClient("bob")
        groupScenario(alice, bob, label)
    }
}

if (failures > 0) {
    println("$failures scenario(s) failed")
    kotlin.system.exitProcess(1)
} else {
    println("All Kotlin scenarios passed.")
}
