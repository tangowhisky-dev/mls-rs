//
//  ServerIntegrationExample.swift
//  MLS Server Integration Example
//
//  This file demonstrates how to implement HTTP-based server communication
//  for MLS key exchange and message distribution using the actual UniFFI bindings.
//
//  NOTE: This example uses the CORRECT method names from the generated bindings.
//  Some examples in /examples/ may use different naming conventions.
//
//  Key differences from existing examples:
//  - Uses correct Swift method names (createGroup, not create_group)
//  - Uses Message.toBytes()/fromBytes() for serialization
//  - Follows the actual generated API signatures
//
//  This example uses the real MLS APIs from the generated Swift bindings:
//  - Client class with proper constructor and methods
//  - Group class with encryption/decryption methods
//  - Message type for MLS protocol messages
//  - Proper error handling and async patterns
//

import Foundation
import mls_rs_uniffi

// MARK: - Data Structures

/// Server message envelope for API communication
struct ServerMessageEnvelope: Codable {
    let id: String
    let groupId: String
    let senderId: String
    let messageType: String // "application", "commit", "proposal", "welcome"
    let encryptedMessage: Data
    let timestamp: Date
    let sequenceNumber: Int64

    enum CodingKeys: String, CodingKey {
        case id, groupId, senderId, messageType, encryptedMessage, timestamp, sequenceNumber
    }
}

/// Welcome message envelope
struct WelcomeMessageEnvelope: Codable {
    let id: String
    let groupId: String
    let memberId: String
    let welcomeMessage: Data
    let timestamp: Date
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, groupId, memberId, welcomeMessage, timestamp, expiresAt
    }
}

/// API response wrapper
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T?
    let error: String?
    let timestamp: Date

    enum CodingKeys: String, CodingKey {
        case success, data, error, timestamp
    }
}

// MARK: - HTTP Delivery Service

/// HTTP-based implementation of MLS Delivery Service
class HTTPDeliveryService {
    private let baseURL: URL
    private let session: URLSession
    private let authToken: String

    init(baseURL: URL, authToken: String) {
        self.baseURL = baseURL
        self.authToken = authToken

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30.0
        config.timeoutIntervalForResource = 300.0
        self.session = URLSession(configuration: config)
    }

    // MARK: - Key Package Management

    func publishKeyPackage(userId: String, keyPackage: Message) async throws {
        let endpoint = baseURL.appendingPathComponent("users/\(userId)/key-packages")
        var request = try createRequest(url: endpoint, method: "POST")

        let body = ["keyPackage": keyPackage.toBytes()]
        request.httpBody = try JSONEncoder().encode(body)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func fetchKeyPackages(userIds: [String]) async throws -> [Message] {
        let endpoint = baseURL.appendingPathComponent("key-packages")
        var request = try createRequest(url: endpoint, method: "GET")

        let queryItems = userIds.map { URLQueryItem(name: "userId", value: $0) }
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems
        request.url = components?.url

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse: APIResponse<[Data]> = try decodeResponse(data)
        guard let keyPackageDatas = apiResponse.data else {
            throw MLSError.invalidResponse("No key packages in response")
        }

        return try keyPackageDatas.map { try Message.fromBytes(bytes: $0) }
    }

    // MARK: - Message Distribution

    func sendMessage(groupId: String, message: Message, senderId: String) async throws {
        let endpoint = baseURL.appendingPathComponent("groups/\(groupId)/messages")
        var request = try createRequest(url: endpoint, method: "POST")

        let envelope = ServerMessageEnvelope(
            id: UUID().uuidString,
            groupId: groupId,
            senderId: senderId,
            messageType: "application",
            encryptedMessage: message.toBytes(),
            timestamp: Date(),
            sequenceNumber: 0
        )

        request.httpBody = try JSONEncoder().encode(envelope)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func fetchMessages(groupId: String, since: Int64) async throws -> [ServerMessageEnvelope] {
        let endpoint = baseURL.appendingPathComponent("groups/\(groupId)/messages")
        var request = try createRequest(url: endpoint, method: "GET")

        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: true)
        components?.queryItems = [URLQueryItem(name: "since", value: String(since))]
        request.url = components?.url

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let apiResponse: APIResponse<[ServerMessageEnvelope]> = try decodeResponse(data)
        return apiResponse.data ?? []
    }

    // MARK: - Welcome Messages

    func sendWelcomeMessage(groupId: String, memberId: String, welcome: Message) async throws {
        let endpoint = baseURL.appendingPathComponent("groups/\(groupId)/welcome/\(memberId)")
        var request = try createRequest(url: endpoint, method: "POST")

        let envelope = WelcomeMessageEnvelope(
            id: UUID().uuidString,
            groupId: groupId,
            memberId: memberId,
            welcomeMessage: welcome.toBytes(),
            timestamp: Date(),
            expiresAt: Date().addingTimeInterval(3600)
        )

        request.httpBody = try JSONEncoder().encode(envelope)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    func fetchWelcomeMessage(groupId: String, memberId: String) async throws -> Message? {
        let endpoint = baseURL.appendingPathComponent("groups/\(groupId)/welcome/\(memberId)")
        let request = try createRequest(url: endpoint, method: "GET")

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
            return nil
        }

        try validateResponse(response)

        let apiResponse: APIResponse<WelcomeMessageEnvelope> = try decodeResponse(data)
        guard let envelope = apiResponse.data else {
            return nil
        }

        return try Message.fromBytes(bytes: envelope.welcomeMessage)
    }

    // MARK: - Helper Methods

    private func createRequest(url: URL, method: String) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MLSError.networkError("Invalid response type")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw MLSError.serverError("HTTP \(httpResponse.statusCode): \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))")
        }
    }

    private func decodeResponse<T: Codable>(_ data: Data) throws -> APIResponse<T> {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(APIResponse<T>.self, from: data)
    }
}

// MARK: - MLS Manager

/// High-level MLS manager coordinating client operations with server communication
class MLSManager {
    private let deliveryService: HTTPDeliveryService
    private let client: Client
    private var groups: [String: Group] = [:]
    private var lastSequenceNumbers: [String: Int64] = [:]

    init(deliveryService: HTTPDeliveryService, client: Client) {
        self.deliveryService = deliveryService
        self.client = client
    }

    // MARK: - Group Management

    func createGroup(name: String? = nil, memberIds: [String]) async throws -> String {
        let keyPackages = try await deliveryService.fetchKeyPackages(userIds: memberIds)

        let groupIdData = name?.data(using: .utf8)
        let group = try client.createGroup(groupId: groupIdData)

        let commitOutput = try group.addMembers(keyPackages: keyPackages)

        let groupId = name ?? UUID().uuidString

        try await deliveryService.sendMessage(
            groupId: groupId,
            message: commitOutput.commitMessage,
            senderId: String(data: client.id, encoding: .utf8) ?? "unknown"
        )

        // Send individual welcome messages (same message to each new member)
        if let welcomeMessage = commitOutput.welcomeMessage {
            for memberId in memberIds {
                try await deliveryService.sendWelcomeMessage(
                    groupId: groupId,
                    memberId: memberId,
                    welcome: welcomeMessage
                )
            }
        }

        groups[groupId] = group
        lastSequenceNumbers[groupId] = 0

        return groupId
    }

    func joinGroup(groupId: String) async throws {
        guard let welcomeMessage = try await deliveryService.fetchWelcomeMessage(
            groupId: groupId,
            memberId: String(data: client.id, encoding: .utf8) ?? "unknown"
        ) else {
            throw MLSError.invalidState("No welcome message found for group \(groupId)")
        }

        let joinInfo = try client.joinGroup(ratchetTree: nil, welcomeMessage: welcomeMessage)
        groups[groupId] = joinInfo.group
        lastSequenceNumbers[groupId] = 0
    }

    // MARK: - Message Operations

    func sendMessage(groupId: String, content: String) async throws {
        guard let group = groups[groupId] else {
            throw MLSError.invalidState("Group \(groupId) not found")
        }

        let data = content.data(using: .utf8) ?? Data()
        let encryptedMessage = try group.encryptApplicationMessage(message: data)

        let senderId = String(data: client.id, encoding: .utf8) ?? "unknown"
        try await deliveryService.sendMessage(
            groupId: groupId,
            message: encryptedMessage,
            senderId: senderId
        )
    }

    func syncMessages() async throws {
        for groupId in groups.keys {
            try await syncMessages(for: groupId)
        }
    }

    private func syncMessages(for groupId: String) async throws {
        guard let group = groups[groupId] else { return }

        let since = lastSequenceNumbers[groupId] ?? 0
        let messages = try await deliveryService.fetchMessages(groupId: groupId, since: since)

        for envelope in messages.sorted(by: { $0.sequenceNumber < $1.sequenceNumber }) {
            try await processMessage(envelope)
            lastSequenceNumbers[groupId] = max(lastSequenceNumbers[groupId] ?? 0, envelope.sequenceNumber)
        }
    }

    private func processMessage(_ envelope: ServerMessageEnvelope) async throws {
        guard let group = groups[envelope.groupId] else { return }

        let message = try Message.fromBytes(bytes: envelope.encryptedMessage)
        let result = try group.processIncomingMessage(message: message)

        switch result {
        case .applicationMessage(let data):
            if let content = String(data: data, encoding: .utf8) {
                print("Received message from \(envelope.senderId): \(content)")
            }

        case .commit:
            print("Group updated by \(envelope.senderId)")
            try group.writeToStorage()

        case .receivedProposal:
            print("Proposal received from \(envelope.senderId)")

        default:
            break
        }
    }

    // MARK: - Utility Methods

    func getGroups() -> [String] {
        return Array(groups.keys)
    }

    func getGroup(_ groupId: String) -> Group? {
        return groups[groupId]
    }
}

// MARK: - Error Types

enum MLSError: Error {
    case networkError(String)
    case serverError(String)
    case invalidResponse(String)
    case invalidState(String)
    case encodingError(String)
}

// MARK: - Usage Example

extension MLSManager {
    /// Example usage demonstrating the complete MLS flow with real APIs
    static func exampleUsage() async throws {
        let baseURL = URL(string: "https://your-mls-server.com/api")!
        let deliveryService = HTTPDeliveryService(baseURL: baseURL, authToken: "your-auth-token")

        // Create signature keypair using actual API
        let keypair = try generateSignatureKeypair(cipherSuite: .p256Aes128)

        // Create client using actual constructor
        let clientId = "alice".data(using: .utf8)!
        let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: clientConfigDefault())

        let manager = MLSManager(deliveryService: deliveryService, client: client)

        // Generate and publish key package
        let keyPackage = try client.generateKeyPackageMessage()
        try await deliveryService.publishKeyPackage(userId: "alice", keyPackage: keyPackage)

        // Create group with members
        let groupId = try await manager.createGroup(memberIds: ["bob"])

        // Bob would join using separate client/session
        // try await manager.joinGroup(groupId: groupId)

        // Send encrypted message
        try await manager.sendMessage(groupId: groupId, content: "Hello, Bob!")

        // Sync messages
        try await manager.syncMessages()
    }
}
