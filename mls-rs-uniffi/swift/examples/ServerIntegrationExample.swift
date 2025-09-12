// MARK: - Server Communication Models
struct ServerMessage: Codable {
    let id: String
    let groupId: String
    let senderId: String
    let messageType: String
    let encryptedData: String  // Base64 encoded MLS message
    let sequenceNumber: Int64
    let timestamp: Date
}

struct KeyPackageResponse: Codable {
    let userId: String
    let keyPackageData: String  // Base64 encoded
    let expiresAt: Date
}

struct WelcomeMessageRequest: Codable {
    let groupId: String
    let memberId: String
    let welcomeData: String  // Base64 encoded
}

// MARK: - Delivery Service Protocol
protocol MLSDeliveryService {
    func publishKeyPackage(userId: String, keyPackage: Message) async throws
    func fetchKeyPackages(userIds: [String]) async throws -> [Message]
    func sendMessage(groupId: String, message: Message, senderId: String) async throws
    func fetchMessages(groupId: String, since: Date) async throws -> [ServerMessage]
    func sendWelcomeMessage(groupId: String, memberId: String, welcomeMessage: Message) async throws
    func fetchWelcomeMessage(groupId: String, memberId: String) async throws -> Message?
}

// MARK: - HTTP Delivery Service Implementation
class HTTPDeliveryService: MLSDeliveryService {
    private let baseURL: URL
    private let session: URLSession
    private let authToken: String

    init(baseURL: URL, authToken: String) {
        self.baseURL = baseURL
        self.authToken = authToken
        self.session = URLSession(configuration: .default)
    }

    func publishKeyPackage(userId: String, keyPackage: Message) async throws {
        let endpoint = baseURL.appendingPathComponent("users/\(userId)/key-packages")

        // Convert MLS message to base64
        let messageData = try JSONEncoder().encode(keyPackage)
        let base64Data = messageData.base64EncodedString()

        let requestBody = ["keyPackageData": base64Data]
        try await performRequest(endpoint, method: "POST", body: requestBody)
    }

    func fetchKeyPackages(userIds: [String]) async throws -> [Message] {
        let endpoint = baseURL.appendingPathComponent("key-packages")
        let queryItems = userIds.map { URLQueryItem(name: "userId", value: $0) }
        var urlComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: true)!
        urlComponents.queryItems = queryItems

        let data = try await performRequest(urlComponents.url!, method: "GET")
        let responses = try JSONDecoder().decode([KeyPackageResponse].self, from: data)

        return try responses.map { response in
            let messageData = Data(base64Encoded: response.keyPackageData)!
            return try JSONDecoder().decode(Message.self, from: messageData)
        }
    }

    func sendMessage(groupId: String, message: Message, senderId: String) async throws {
        let endpoint = baseURL.appendingPathComponent("groups/\(groupId)/messages")

        let messageData = try JSONEncoder().encode(message)
        let base64Data = messageData.base64EncodedString()

        let requestBody = [
            "senderId": senderId,
            "encryptedData": base64Data,
            "messageType": "application"
        ]

        try await performRequest(endpoint, method: "POST", body: requestBody)
    }

    func fetchMessages(groupId: String, since: Date) async throws -> [ServerMessage] {
        let endpoint = baseURL.appendingPathComponent("groups/\(groupId)/messages")
        var urlComponents = URLComponents(url: endpoint, resolvingAgainstBaseURL: true)!
        urlComponents.queryItems = [
            URLQueryItem(name: "since", value: ISO8601DateFormatter().string(from: since))
        ]

        let data = try await performRequest(urlComponents.url!, method: "GET")
        return try JSONDecoder().decode([ServerMessage].self, from: data)
    }

    func sendWelcomeMessage(groupId: String, memberId: String, welcomeMessage: Message) async throws {
        let endpoint = baseURL.appendingPathComponent("groups/\(groupId)/welcome/\(memberId)")

        let messageData = try JSONEncoder().encode(welcomeMessage)
        let base64Data = messageData.base64EncodedString()

        let requestBody = ["welcomeData": base64Data]
        try await performRequest(endpoint, method: "POST", body: requestBody)
    }

    func fetchWelcomeMessage(groupId: String, memberId: String) async throws -> Message? {
        let endpoint = baseURL.appendingPathComponent("groups/\(groupId)/welcome/\(memberId)")

        do {
            let data = try await performRequest(endpoint, method: "GET")
            let response = try JSONDecoder().decode(WelcomeMessageRequest.self, from: data)
            let messageData = Data(base64Encoded: response.welcomeData)!
            return try JSONDecoder().decode(Message.self, from: messageData)
        } catch let error as HTTPError where error.statusCode == 404 {
            return nil  // No welcome message available
        }
    }

    // MARK: - Private Helpers
    private func performRequest(_ url: URL, method: String, body: [String: Any]? = nil) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw HTTPError.statusCode(httpResponse.statusCode)
        }

        return data
    }
}

// MARK: - Error Types
enum HTTPError: Error {
    case invalidResponse
    case statusCode(Int)
    case networkError(Error)
}

// MARK: - MLS Manager Integration
class MLSManager {
    private let deliveryService: MLSDeliveryService
    private let client: Client
    private var groups: [String: Group] = [:]
    private var messageProcessor: MLSMessageProcessor

    init(deliveryService: MLSDeliveryService, client: Client) {
        self.deliveryService = deliveryService
        self.client = client
        self.messageProcessor = MLSMessageProcessor(deliveryService: deliveryService, groups: groups)
    }

    // MARK: - Group Management
    func createGroup(name: String, memberIds: [String]) async throws -> String {
        print("🔐 Creating MLS group: \(name)")

        // 1. Create MLS group
        let group = try client.createGroup(groupId: nil)
        let groupId = UUID().uuidString

        // 2. Fetch key packages for members
        print("📦 Fetching key packages for \(memberIds.count) members")
        let keyPackages = try await deliveryService.fetchKeyPackages(userIds: memberIds)

        // 3. Add members to group
        print("👥 Adding members to group")
        let commitOutput = try group.addMembers(keyPackages: keyPackages)

        // 4. Send welcome messages to new members
        if let welcomeMessage = commitOutput.welcome_message {
            print("📨 Sending welcome messages")
            for memberId in memberIds {
                try await deliveryService.sendWelcomeMessage(
                    groupId: groupId,
                    memberId: memberId,
                    welcomeMessage: welcomeMessage
                )
            }
        }

        // 5. Send commit message to all members
        print("📤 Sending commit message")
        try await deliveryService.sendMessage(
            groupId: groupId,
            message: commitOutput.commit_message,
            senderId: getCurrentUserId()
        )

        // 6. Store group locally
        try group.writeToStorage()
        groups[groupId] = group

        print("✅ Group created successfully: \(groupId)")
        return groupId
    }

    func joinGroup(groupId: String) async throws {
        print("🔑 Joining group: \(groupId)")

        // 1. Fetch welcome message
        guard let welcomeMessage = try await deliveryService.fetchWelcomeMessage(
            groupId: groupId,
            memberId: getCurrentUserId()
        ) else {
            throw MLSError.noWelcomeMessage
        }

        // 2. Join the group
        let joinInfo = try client.joinGroup(
            ratchetTree: nil,
            welcomeMessage: welcomeMessage
        )

        // 3. Store the group
        try joinInfo.group.writeToStorage()
        groups[groupId] = joinInfo.group

        print("✅ Successfully joined group: \(groupId)")
    }

    // MARK: - Messaging
    func sendMessage(groupId: String, content: String) async throws {
        guard let group = groups[groupId] else {
            throw MLSError.groupNotFound
        }

        print("📤 Sending message to group: \(groupId)")

        // 1. Encrypt the message
        let messageData = Array(content.utf8)
        let encryptedMessage = try group.encryptApplicationMessage(message: messageData)

        // 2. Send via delivery service
        try await deliveryService.sendMessage(
            groupId: groupId,
            message: encryptedMessage,
            senderId: getCurrentUserId()
        )

        // 3. Persist group state
        try group.writeToStorage()

        print("✅ Message sent successfully")
    }

    func syncMessages() async throws {
        print("🔄 Syncing messages for all groups")

        for groupId in groups.keys {
            let messages = try await deliveryService.fetchMessages(
                groupId: groupId,
                since: getLastSyncTimestamp(for: groupId)
            )

            for serverMessage in messages {
                try await processServerMessage(serverMessage)
            }

            updateLastSyncTimestamp(for: groupId, timestamp: Date())
        }

        print("✅ Message sync completed")
    }

    // MARK: - Private Methods
    private func processServerMessage(_ serverMessage: ServerMessage) async throws {
        guard let group = groups[serverMessage.groupId] else { return }

        // Decode the encrypted message
        let messageData = Data(base64Encoded: serverMessage.encryptedData)!
        let message = try JSONDecoder().decode(Message.self, from: messageData)

        // Process the message
        let result = try group.processIncomingMessage(message: message)

        switch result {
        case .applicationMessage(let sender, let data):
            let content = String(data: Data(data), encoding: .utf8) ?? "[Invalid UTF-8]"
            print("📨 Received message from \(sender): \(content)")
            // Handle received message in UI

        case .commit(let committer, let effect):
            print("🔄 Group updated by \(committer)")
            try group.writeToStorage()

        case .receivedProposal(let sender, let proposal):
            print("💡 Proposal received from \(sender)")
            // Handle proposal (e.g., member addition/removal)

        default:
            print("ℹ️ Other message type received")
        }
    }

    private func getCurrentUserId() -> String {
        // Return current user's ID
        return "current_user_id"
    }

    private func getLastSyncTimestamp(for groupId: String) -> Date {
        // Return last sync timestamp for the group
        return Date(timeIntervalSinceNow: -3600) // 1 hour ago
    }

    private func updateLastSyncTimestamp(for groupId: String, timestamp: Date) {
        // Store the last sync timestamp
        // This should be persisted (UserDefaults, database, etc.)
    }
}

// MARK: - Error Types
enum MLSError: Error {
    case groupNotFound
    case noWelcomeMessage
    case invalidMessage
    case networkError(Error)
}

// MARK: - Usage Example
func exampleUsage() async throws {
    // 1. Setup delivery service
    let baseURL = URL(string: "https://api.yourserver.com/mls")!
    let deliveryService = HTTPDeliveryService(
        baseURL: baseURL,
        authToken: "your_auth_token"
    )

    // 2. Create MLS client with custom storage
    let storage = RealmGroupStateStorage() // From previous example
    let config = ClientConfig(
        groupStateStorage: storage,
        useRatchetTreeExtension: true
    )

    let keypair = try generateSignatureKeypair(cipherSuite: .p256Aes128)
    let client = Client(
        id: Array("alice".utf8),
        signatureKeypair: keypair,
        clientConfig: config
    )

    // 3. Create MLS manager
    let mlsManager = MLSManager(deliveryService: deliveryService, client: client)

    // 4. Create a group
    let groupId = try await mlsManager.createGroup(
        name: "My Chat Group",
        memberIds: ["bob", "charlie"]
    )

    // 5. Send a message
    try await mlsManager.sendMessage(
        groupId: groupId,
        content: "Hello, everyone! 👋"
    )

    // 6. Sync messages periodically
    Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
        Task {
            try await mlsManager.syncMessages()
        }
    }
}

// MARK: - Data Extension
extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
}
