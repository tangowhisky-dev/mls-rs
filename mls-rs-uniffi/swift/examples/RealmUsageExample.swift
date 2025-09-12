// Example usage with Realm storage
func exampleUsage() throws {
    // Initialize Realm with proper configuration
    let realmConfiguration = Realm.Configuration(
        schemaVersion: 1,
        migrationBlock: { migration, oldSchemaVersion in
            // Handle migrations if needed
        }
    )
    let realm = try Realm(configuration: realmConfiguration)

    // Create custom storage
    let storage = try RealmGroupStateStorage(realmConfiguration: realmConfiguration)

    // Create client configuration with custom storage
    let config = ClientConfig(
        groupStateStorage: storage,
        useRatchetTreeExtension: true
    )

    // Generate keypairs for users
    let aliceKeypair = try generateSignatureKeypair(cipherSuite: .p256Aes128)
    let bobKeypair = try generateSignatureKeypair(cipherSuite: .p256Aes128)

    // Create clients
    let alice = Client(
        id: "alice".data(using: .utf8)!,
        signatureKeypair: aliceKeypair,
        clientConfig: config
    )

    let bob = Client(
        id: "bob".data(using: .utf8)!,
        signatureKeypair: bobKeypair,
        clientConfig: config
    )

    // Create a group - data will be stored in Realm
    let group = try alice.createGroup(groupId: nil)

    // Add Bob to the group
    let bobKeyPackage = try bob.generateKeyPackageMessage()
    let commit = try group.addMembers(keyPackages: [bobKeyPackage])

    // Process the commit
    _ = try alice.processIncomingMessage(message: commit.commitMessage)

    // Bob joins using welcome message
    let joinInfo = try bob.joinGroup(
        ratchetTree: nil,
        welcomeMessage: commit.welcomeMessage!
    )

    // Send encrypted messages - all state persisted to Realm
    let message = "Hello from Alice!".data(using: .utf8)!
    let encrypted = try group.encryptApplicationMessage(message: message)

    // Persist group state to Realm (optional - happens automatically)
    try group.writeToStorage()

    print("✅ All MLS operations completed with Realm storage!")
}

// MARK: - Data Extension
extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
