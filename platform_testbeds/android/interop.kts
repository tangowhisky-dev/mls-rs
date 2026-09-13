// Cross-language wire-interop consumer for the Kotlin bindings.
//
// Flow (scripts/test_interop.sh sets MLS_FIXTURE_DIR/MLS_SUITE and
// builds the Rust harness first):
//   1. This client generates a key package and writes the raw wire
//      bytes as `consumer_kp_kotlin.bin`.
//   2. The Rust harness (--make-welcome) parses that key package,
//      adds it to a fresh group and writes welcome/commit/app_msg
//      wire bytes.
//   3. This client parses the welcome via Message.fromBytes, joins
//      the group and decrypts the Rust-produced application message.
//
// Proves: Rust consumed Kotlin-produced bytes and Kotlin consumed
// Rust-produced bytes — the real network boundary.

import uniffi.mls_rs_uniffi.*
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.Paths

val fixtureDir: Path = Paths.get(System.getenv("MLS_FIXTURE_DIR") ?: "interop/fixtures")
val harnessBin: String = System.getenv("MLS_HARNESS_BIN")
    ?: throw IllegalStateException("MLS_HARNESS_BIN not set")
val suiteName: String = System.getenv("MLS_SUITE") ?: "Curve25519Aes128"

fun fixtureBytes(name: String): ByteArray = Files.readAllBytes(fixtureDir.resolve(name))

fun suiteOf(name: String): CipherSuite = when (name.trim()) {
    "Curve25519Aes128" -> CipherSuite.CURVE25519_AES128
    "P256Aes128" -> CipherSuite.P256_AES128
    "Curve25519ChaCha" -> CipherSuite.CURVE25519_CHA_CHA
    "P521Aes256" -> CipherSuite.P521_AES256
    "P384Aes256" -> CipherSuite.P384_AES256
    else -> throw IllegalArgumentException("unknown suite: $name")
}

fun assertTrue(cond: Boolean, label: String) {
    if (!cond) throw AssertionError(label)
}

// Phase 1: emit this client's key package as raw MLS wire bytes.
val suite = suiteOf(suiteName)
val myId = "bob-kotlin".toByteArray()
val bob = Client(myId, generateSignatureKeypair(suite), clientConfigDefault())
Files.write(fixtureDir.resolve("consumer_kp_kotlin.bin"),
    bob.generateKeyPackageMessage().toBytes())

// Phase 2: Rust consumes the key package and produces the welcome.
val rc = ProcessBuilder(harnessBin, "--make-welcome", fixtureDir.toString(), suiteName)
    .inheritIO().start().waitFor()
if (rc != 0) throw IllegalStateException("rust harness make-welcome failed: $rc")

// Phase 3: join the group from Rust's serialized welcome.
val ratchetTreeFile = fixtureDir.resolve("ratchet_tree.bin")
val ratchetTree =
    if (Files.exists(ratchetTreeFile)) RatchetTree(Files.readAllBytes(ratchetTreeFile)) else null
val welcome = Message.fromBytes(fixtureBytes("welcome.bin"))
val group = bob.joinGroup(ratchetTree, welcome).group

// Rust's commit bytes must parse cleanly too.
Message.fromBytes(fixtureBytes("commit.bin"))

// Decrypt the application message Alice sent from Rust.
val received = group.processIncomingMessage(Message.fromBytes(fixtureBytes("app_msg.bin")))
val expected = fixtureBytes("plaintext.bin").decodeToString()
when (received) {
    is ReceivedMessage.ApplicationMessage ->
        assertTrue(received.data.decodeToString() == expected, "plaintext mismatch")
    else -> throw AssertionError("expected application message, got $received")
}

// Roster: alice and this client must both resolve by identifier.
val members = group.members()
assertTrue(members.size >= 2, "expected >= 2 members, got ${members.size}")
val alice = group.memberWithIdentity(fixtureBytes("alice_id.bin"))
assertTrue(alice.identifier().decodeToString() == "alice", "alice identifier mismatch")

// --- Differential checks against direct-Rust ground truth ---
// Every fixture must round-trip byte-identically through the binding's
// codec, and the post-join ratchet tree must equal what plain mls-rs
// computed for the same inputs.
for (f in listOf("welcome.bin", "commit.bin", "app_msg.bin")) {
    val bytes = fixtureBytes(f)
    assertTrue(Message.fromBytes(bytes).toBytes().contentEquals(bytes),
        "round-trip mismatch: $f")
}
assertTrue(group.exportTree().bytes.contentEquals(fixtureBytes("expected_tree_join.bin")),
    "post-join tree differs from direct-Rust result")

// A second commit produced inside plain mls-rs: processing it must
// drive this client to the identical tree and roster.
group.processIncomingMessage(Message.fromBytes(fixtureBytes("commit2.bin")))
assertTrue(group.exportTree().bytes.contentEquals(fixtureBytes("expected_tree_final.bin")),
    "post-commit2 tree differs from direct-Rust result")
val expectedRoster = fixtureBytes("expected_roster.txt").decodeToString().split("\n").sorted()
val actualRoster = group.members().map { it.identifier().decodeToString() }.sorted()
assertTrue(actualRoster == expectedRoster,
    "roster mismatch: $actualRoster != $expectedRoster")
val msg2 = group.processIncomingMessage(Message.fromBytes(fixtureBytes("app_msg2.bin")))
assertTrue(msg2 is ReceivedMessage.ApplicationMessage &&
    msg2.data.decodeToString() == fixtureBytes("plaintext2.bin").decodeToString(),
    "epoch-2 plaintext mismatch")

// Reverse direction: this binding's encrypted output must be
// decryptable by the direct Rust library.
Files.write(fixtureDir.resolve("consumer_msg_kotlin.bin"),
    group.encryptApplicationMessage("hello from kotlin".toByteArray()).toBytes())
val vrc = ProcessBuilder(harnessBin, "--verify", fixtureDir.toString(), suiteName)
    .inheritIO().start().waitFor()
assertTrue(vrc == 0, "rust --verify failed: $vrc")

println("PASS kotlin interop + differential (Rust consumed KP+msg, Kotlin matched golden outputs)")
