// MLSRealmStorage.swift
import Foundation
import RealmSwift
import mls_rs_uniffi

// MARK: - Realm Models
class GroupStateObject: Object {
    @Persisted(primaryKey: true) var groupId: String = ""
    @Persisted var stateData: Data = Data()
    @Persisted var lastModified: Date = Date()

    convenience init(groupId: String, stateData: Data) {
        self.init()
        self.groupId = groupId
        self.stateData = stateData
        self.lastModified = Date()
    }
}

class EpochObject: Object {
    @Persisted(primaryKey: true) var id: String = "" // "groupId_epochId"
    @Persisted var groupId: String = ""
    @Persisted var epochId: UInt64 = 0
    @Persisted var epochData: Data = Data()
    @Persisted var lastModified: Date = Date()

    convenience init(groupId: String, epochId: UInt64, epochData: Data) {
        self.init()
        self.id = "\(groupId)_\(epochId)"
        self.groupId = groupId
        self.epochId = epochId
        self.epochData = epochData
        self.lastModified = Date()
    }
}

// MARK: - Custom Storage Implementation
class RealmGroupStateStorage: GroupStateStorage {
    private let realmConfiguration: Realm.Configuration

    init(realmConfiguration: Realm.Configuration) {
        self.realmConfiguration = realmConfiguration
    }

    // Required by UniFFI - default Realm configuration
    convenience init() throws {
        let config = Realm.Configuration(
            schemaVersion: 1,
            migrationBlock: { migration, oldSchemaVersion in
                // Handle migrations if needed
            }
        )
        self.init(realmConfiguration: config)
    }

    // MARK: - GroupStateStorage Protocol Implementation

    func state(groupId: Data) throws -> Data? {
        let groupIdString = groupId.hexString
        let realm = try Realm(configuration: realmConfiguration)
        return realm.objects(GroupStateObject.self)
            .filter("groupId == %@", groupIdString)
            .first?.stateData
    }

    func epoch(groupId: Data, epochId: UInt64) throws -> Data? {
        let groupIdString = groupId.hexString
        let realm = try Realm(configuration: realmConfiguration)
        return realm.objects(EpochObject.self)
            .filter("groupId == %@ AND epochId == %lld", groupIdString, epochId)
            .first?.epochData
    }

    func write(groupId: Data, groupState: Data, epochInserts: [EpochRecord], epochUpdates: [EpochRecord]) throws {
        let groupIdString = groupId.hexString
        let realm = try Realm(configuration: realmConfiguration)

        try realm.write {
            // Write group state
            let groupStateObj = GroupStateObject(
                groupId: groupIdString,
                stateData: groupState
            )
            realm.add(groupStateObj, update: .modified)

            // Handle epoch inserts
            for epochRecord in epochInserts {
                let epochObj = EpochObject(
                    groupId: groupIdString,
                    epochId: epochRecord.id,
                    epochData: epochRecord.data
                )
                realm.add(epochObj, update: .modified)
            }

            // Handle epoch updates
            for epochRecord in epochUpdates {
                if let existingEpoch = realm.objects(EpochObject.self)
                    .filter("groupId == %@ AND epochId == %lld", groupIdString, epochRecord.id)
                    .first {
                    existingEpoch.epochData = epochRecord.data
                    existingEpoch.lastModified = Date()
                }
            }
        }
    }

    func maxEpochId(groupId: Data) throws -> UInt64? {
        let groupIdString = groupId.hexString
        let realm = try Realm(configuration: realmConfiguration)
        return realm.objects(EpochObject.self)
            .filter("groupId == %@", groupIdString)
            .max(ofProperty: "epochId") as UInt64?
    }

    // MARK: - Helper Methods
    private func dataToHexString(_ data: Data) -> String {
        return data.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Usage Example
class MLSManager {
    private let realmConfiguration: Realm.Configuration
    private var clients: [String: Client] = [:]

    init(realmConfiguration: Realm.Configuration) {
        self.realmConfiguration = realmConfiguration
    }

    func createClient(userId: String, cipherSuite: CipherSuite) throws -> Client {
        // Create custom Realm storage
        let storage = try RealmGroupStateStorage(realmConfiguration: realmConfiguration)

        // Create client configuration with custom storage
        let config = ClientConfig(
            groupStateStorage: storage,
            useRatchetTreeExtension: true
        )

        // Generate keypair
        let keypair = try generateSignatureKeypair(cipherSuite: cipherSuite)

        // Create client
        let client = Client(
            id: Array(userId.utf8),
            signatureKeypair: keypair,
            clientConfig: config
        )

        clients[userId] = client
        return client
    }

    func getClient(userId: String) -> Client? {
        return clients[userId]
    }
}

// MARK: - Data Extension
extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Data Extension
extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
