// XCTest end-to-end suite for the generated Swift UniFFI bindings —
// all five RustCrypto cipher suites plus X.509 clients. Runs on iOS
// simulators and macOS via `xcodebuild test`.

import Foundation
import XCTest

@testable import mls_rs_uniffi

final class MlsRsE2ETests: XCTestCase {
    private var pkiBase: URL {
        Bundle.module.resourceURL!.appendingPathComponent("test_pki")
    }

    private func cert(_ name: String) throws -> Data {
        try Data(contentsOf: pkiBase.appendingPathComponent(name).appendingPathComponent("cert.der"))
    }

    private func keyMaterial(_ name: String, _ file: String) throws -> Data {
        try Data(contentsOf: pkiBase.appendingPathComponent(name).appendingPathComponent(file))
    }

    func groupScenario(alice: Client, bob: Client, label: String) throws {
        let aliceGroup = try alice.createGroup(groupId: nil)
        let bobKeyPackage = try bob.generateKeyPackageMessage()

        let commit = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])
        _ = try aliceGroup.processIncomingMessage(message: commit.commitMessage)
        let bobGroup = try bob.joinGroup(ratchetTree: nil, welcomeMessage: commit.welcomeMessage!)
            .group

        let encrypted = try aliceGroup.encryptApplicationMessage(message: Data("hello, bob".utf8))
        let received = try bobGroup.processIncomingMessage(message: encrypted)
        guard case .applicationMessage(_, let data) = received else {
            return XCTFail("\(label): expected application message, got \(received)")
        }
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "hello, bob")

        try aliceGroup.writeToStorage()
        try bobGroup.writeToStorage()
    }

    func testAllCipherSuites() throws {
        for suite: CipherSuite in [
            .curve25519Aes128, .p256Aes128, .curve25519ChaCha, .p521Aes256, .p384Aes256,
        ] {
            let aliceKey = try generateSignatureKeypair(cipherSuite: suite)
            let alice = try Client(
                id: Data("alice".utf8), signatureKeypair: aliceKey,
                clientConfig: clientConfigDefault())
            let bobKey = try generateSignatureKeypair(cipherSuite: suite)
            let bob = try Client(
                id: Data("bob".utf8), signatureKeypair: bobKey,
                clientConfig: clientConfigDefault())
            try groupScenario(alice: alice, bob: bob, label: "\(suite)")
        }
    }

    func testX509Identities() throws {
        for (curve, suite): (String, CipherSuite) in [
            ("ed25519", .curve25519Aes128),
            ("ed25519", .curve25519ChaCha),
            ("p256", .p256Aes128),
            ("p384", .p384Aes256),
            ("p521", .p521Aes256),
        ] {
            let rootCa = try cert("\(curve)_ca")
            var config = clientConfigDefault()
            config.rootCaCertificates = [rootCa]

            func makeClient(_ who: String) throws -> Client {
                let cert = try self.cert("\(curve)_\(who)")
                let keypair = SignatureKeypair(
                    cipherSuite: suite,
                    publicKey: SignaturePublicKey(
                        bytes: try self.keyMaterial("\(curve)_\(who)", "public.bin")),
                    secretKey: SignatureSecretKey(
                        bytes: try self.keyMaterial("\(curve)_\(who)", "secret.bin")))
                return try Client.newWithX509(
                    certificateChain: [cert], signatureKeypair: keypair, clientConfig: config)
            }

            try groupScenario(
                alice: makeClient("alice"), bob: makeClient("bob"),
                label: "x509-\(curve)-\(suite)")
        }
    }
}
