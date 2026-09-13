// Cross-language wire-interop consumer for the Swift bindings.
//
// Flow (scripts/test_interop.sh sets MLS_FIXTURE_DIR/MLS_SUITE and
// builds the Rust harness first):
//   1. This client generates a key package and writes the raw wire
//      bytes as `consumer_kp_swift.bin`.
//   2. The Rust harness (--make-welcome) parses that key package,
//      adds it to a fresh group and writes welcome/commit/app_msg
//      wire bytes.
//   3. This client parses the welcome via Message.fromBytes, joins
//      the group and decrypts the Rust-produced application message.

import Foundation
import mls_rs_uniffi

let env = ProcessInfo.processInfo.environment
let fixtureDir = URL(fileURLWithPath: env["MLS_FIXTURE_DIR"] ?? "interop/fixtures")
let harnessBin = env["MLS_HARNESS_BIN"]!
let suiteName = env["MLS_SUITE"] ?? "Curve25519Aes128"

func fixtureBytes(_ name: String) throws -> Data {
    try Data(contentsOf: fixtureDir.appendingPathComponent(name))
}

func suiteOf(_ name: String) throws -> CipherSuite {
    switch name.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "Curve25519Aes128": return .curve25519Aes128
    case "P256Aes128": return .p256Aes128
    case "Curve25519ChaCha": return .curve25519ChaCha
    case "P521Aes256": return .p521Aes256
    case "P384Aes256": return .p384Aes256
    default: throw NSError(domain: "interop", code: 1, userInfo: nil)
    }
}

func assertTrue(_ cond: Bool, _ label: String) throws {
    if !cond {
        throw NSError(domain: "interop", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: label])
    }
}

do {
    // Phase 1: emit this client's key package as raw MLS wire bytes.
    let suite = try suiteOf(suiteName)
    let myId = Data("bob-swift".utf8)
    let bob = try Client(
        id: myId,
        signatureKeypair: generateSignatureKeypair(cipherSuite: suite),
        clientConfig: clientConfigDefault())
    try bob.generateKeyPackageMessage().toBytes()
        .write(to: fixtureDir.appendingPathComponent("consumer_kp_swift.bin"))

    // Phase 2: Rust consumes the key package and produces the welcome.
    let harness = Process()
    harness.executableURL = URL(fileURLWithPath: harnessBin)
    harness.arguments = ["--make-welcome", fixtureDir.path, suiteName]
    try harness.run()
    harness.waitUntilExit()
    try assertTrue(
        harness.terminationStatus == 0, "rust harness make-welcome failed")

    // Phase 3: join the group from Rust's serialized welcome.
    let ratchetTreeFile = fixtureDir.appendingPathComponent("ratchet_tree.bin")
    let ratchetTree = FileManager.default.fileExists(atPath: ratchetTreeFile.path)
        ? RatchetTree(bytes: try Data(contentsOf: ratchetTreeFile))
        : nil
    let welcome = try Message.fromBytes(bytes: fixtureBytes("welcome.bin"))
    let group = try bob.joinGroup(ratchetTree: ratchetTree, welcomeMessage: welcome).group

    // Rust's commit bytes must parse cleanly too.
    _ = try Message.fromBytes(bytes: fixtureBytes("commit.bin"))

    // Decrypt the application message Alice sent from Rust.
    let received = try group.processIncomingMessage(
        message: Message.fromBytes(bytes: fixtureBytes("app_msg.bin")))
    guard case .applicationMessage(_, let data) = received else {
        throw NSError(domain: "interop", code: 3, userInfo: nil)
    }
    try assertTrue(data == fixtureBytes("plaintext.bin"), "plaintext mismatch")

    // Roster: alice and this client must both resolve by identifier.
    try assertTrue(group.members().count >= 2, "expected >= 2 members")
    let alice = try group.memberWithIdentity(
        identifier: fixtureBytes("alice_id.bin"))
    try assertTrue(
        alice.identifier() == fixtureBytes("alice_id.bin"),
        "alice identifier mismatch")

    // --- Differential checks against direct-Rust ground truth ---
    // Marshalling must be identity and the post-join ratchet tree must
    // equal what plain mls-rs computed for the same inputs.
    for f in ["welcome.bin", "commit.bin", "app_msg.bin"] {
        let bytes = try fixtureBytes(f)
        try assertTrue(
            Message.fromBytes(bytes: bytes).toBytes() == bytes,
            "round-trip mismatch: \(f)")
    }
    try assertTrue(
        group.exportTree().bytes == fixtureBytes("expected_tree_join.bin"),
        "post-join tree differs from direct-Rust result")

    // Second commit produced inside plain mls-rs: processing it must
    // drive this client to the identical tree and roster.
    _ = try group.processIncomingMessage(
        message: Message.fromBytes(bytes: fixtureBytes("commit2.bin")))
    try assertTrue(
        group.exportTree().bytes == fixtureBytes("expected_tree_final.bin"),
        "post-commit2 tree differs from direct-Rust result")
    let expectedRoster = String(decoding: try fixtureBytes("expected_roster.txt"),
        as: UTF8.self).split(separator: "\n").map(String.init).sorted()
    let actualRoster = try group.members()
        .map { String(decoding: try $0.identifier(), as: UTF8.self) }.sorted()
    try assertTrue(actualRoster == expectedRoster,
        "roster mismatch: \(actualRoster) != \(expectedRoster)")
    let msg2 = try group.processIncomingMessage(
        message: Message.fromBytes(bytes: fixtureBytes("app_msg2.bin")))
    guard case .applicationMessage(_, let data2) = msg2 else {
        throw NSError(domain: "interop", code: 4, userInfo: nil)
    }
    try assertTrue(
        data2 == fixtureBytes("plaintext2.bin"), "epoch-2 plaintext mismatch")

    // Reverse direction: this binding's encrypted output must be
    // decryptable by the direct Rust library.
    try group.encryptApplicationMessage(message: Data("hello from swift".utf8))
        .toBytes().write(
            to: fixtureDir.appendingPathComponent("consumer_msg_swift.bin"))
    let verify = Process()
    verify.executableURL = URL(fileURLWithPath: harnessBin)
    verify.arguments = ["--verify", fixtureDir.path, suiteName]
    try verify.run()
    verify.waitUntilExit()
    try assertTrue(verify.terminationStatus == 0, "rust --verify failed")

    print("PASS swift interop + differential (Rust consumed KP+msg, Swift matched golden outputs)")
} catch {
    print("FAIL swift interop: \(error)")
    Foundation.exit(1)
}
