// End-to-end scenario for the generated Swift UniFFI bindings.
// Exercises all five RustCrypto cipher suites plus X.509 clients.
//
// Run via scripts/test_swift_macos.sh or as part of the iOS
// SwiftPM test package.

import Foundation
import mls_rs_uniffi

let testbedRoot = ProcessInfo.processInfo.environment["MLS_TESTBED_ROOT"]
    .map { URL(fileURLWithPath: $0) } ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

func readBytes(_ parts: String...) throws -> Data {
    let url = parts.reduce(testbedRoot) { $0.appendingPathComponent($1) }
    return try Data(contentsOf: url)
}

func check(_ label: String, _ body: () throws -> Void) -> Bool {
    do {
        try body()
        print("PASS \(label)")
        return true
    } catch {
        print("FAIL \(label): \(error)")
        return false
    }
}

func groupScenario(alice: Client, bob: Client, label: String) throws {
    let aliceGroup = try alice.createGroup(groupId: nil)
    let bobKeyPackage = try bob.generateKeyPackageMessage()

    let commit = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])
    _ = try aliceGroup.processIncomingMessage(message: commit.commitMessage)
    let bobGroup = try bob.joinGroup(ratchetTree: nil, welcomeMessage: commit.welcomeMessage!).group

    let encrypted = try aliceGroup.encryptApplicationMessage(message: Data("hello, bob".utf8))
    let received = try bobGroup.processIncomingMessage(message: encrypted)
    guard case .applicationMessage(_, let data) = received else {
        throw NSError(domain: "e2e", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "\(label): expected application message"])
    }
    if String(decoding: data, as: UTF8.self) != "hello, bob" {
        throw NSError(domain: "e2e", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "\(label): plaintext mismatch"])
    }

    try aliceGroup.writeToStorage()
    try bobGroup.writeToStorage()
}

var failures = 0

let allSuites: [CipherSuite] = [
    .curve25519Aes128, .p256Aes128, .curve25519ChaCha, .p521Aes256, .p384Aes256,
]

for suite in allSuites {
    if !check("basic e2e \(suite)", {
        let aliceKey = try generateSignatureKeypair(cipherSuite: suite)
        let alice = try Client(
            id: Data("alice".utf8), signatureKeypair: aliceKey, clientConfig: clientConfigDefault())
        let bobKey = try generateSignatureKeypair(cipherSuite: suite)
        let bob = try Client(
            id: Data("bob".utf8), signatureKeypair: bobKey, clientConfig: clientConfigDefault())
        try groupScenario(alice: alice, bob: bob, label: "\(suite)")
    }) { failures += 1 }
}

let x509Cases: [(String, CipherSuite, String)] = [
    ("ed25519", .curve25519Aes128, "x509-ed25519-suite1"),
    ("ed25519", .curve25519ChaCha, "x509-ed25519-suite3"),
    ("p256", .p256Aes128, "x509-p256-suite2"),
    ("p384", .p384Aes256, "x509-p384-suite7"),
    ("p521", .p521Aes256, "x509-p521-suite5"),
]

for (curve, suite, label) in x509Cases {
    if !check(label, {
        let rootCa = try readBytes("test_pki", "\(curve)_ca", "cert.der")
        var config = clientConfigDefault()
        config.rootCaCertificates = [rootCa]

        func makeClient(_ who: String) throws -> Client {
            let cert = try readBytes("test_pki", "\(curve)_\(who)", "cert.der")
            let keypair = SignatureKeypair(
                cipherSuite: suite,
                publicKey: SignaturePublicKey(
                    bytes: try readBytes("test_pki", "\(curve)_\(who)", "public.bin")),
                secretKey: SignatureSecretKey(
                    bytes: try readBytes("test_pki", "\(curve)_\(who)", "secret.bin")))
            return try Client.newWithX509(
                certificateChain: [cert], signatureKeypair: keypair, clientConfig: config)
        }

        try groupScenario(alice: makeClient("alice"), bob: makeClient("bob"), label: label)
    }) { failures += 1 }
}

if failures > 0 {
    print("\(failures) scenario(s) failed")
    exit(1)
} else {
    print("All Swift scenarios passed.")
}
