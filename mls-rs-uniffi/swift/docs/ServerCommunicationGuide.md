# MLS Server Communication Architecture

## Overview

The MLS UniFFI wrapper provides **cryptographic operations only**. Server communication and key exchange must be implemented at the application layer. Here's how the complete MLS messaging system works:

## What the Wrapper Provides ✅

### Cryptographic Operations
- **Key Generation**: `generateSignatureKeypair(cipherSuite: CipherSuite)`
- **Key Package Creation**: `client.generateKeyPackageMessage()`
- **Group Management**: `client.createGroup(groupId: Data?)`, `group.addMembers(keyPackages: [Message])`
- **Message Encryption**: `group.encryptApplicationMessage(message: Data)`
- **Message Decryption**: `group.processIncomingMessage(message: Message)`
- **State Management**: `group.writeToStorage()`

### Data Structures
- **Messages**: Encrypted MLS protocol messages (`Message` type)
- **Key Packages**: Public keys for joining groups (`Message` containing key package)
- **Welcome Messages**: Encrypted group state for new members (`Message` in `CommitOutput.welcomeMessage`)
- **Commits**: Group state updates (`CommitOutput.commitMessage`)

### Client API
```swift
// Create client with proper constructor
let client = Client(
    id: "alice".data(using: .utf8)!,
    signatureKeypair: generateSignatureKeypair(cipherSuite: .p256Aes128),
    clientConfig: clientConfigDefault()
)

// Generate key package for joining groups
let keyPackage = try client.generateKeyPackageMessage()

// Create new group
let group = try client.createGroup(groupId: nil)

// Join existing group with welcome message
let joinInfo = try client.joinGroup(ratchetTree: nil, welcomeMessage: welcomeMessage)
let group = joinInfo.group
```

### CommitOutput Structure
```swift
public struct CommitOutput {
    public var commitMessage: Message      // Send to ALL group members
    public var welcomeMessage: Message?    // Send to NEW members only
    public var ratchetTree: RatchetTree?   // Optional ratchet tree
    public var groupInfo: Message?         // Optional group info
}
```

**Important:** When adding multiple members, send the same `welcomeMessage` to each new member individually.

### Group Creation with Multiple Members
```swift
// Add multiple members at once
let commitOutput = try group.addMembers(keyPackages: [aliceKeyPackage, bobKeyPackage])

// Send commit to ALL existing members
try await deliveryService.sendMessage(
    groupId: groupId,
    message: commitOutput.commitMessage,
    senderId: "creator"
)

// Send welcome message to EACH new member individually
if let welcomeMessage = commitOutput.welcomeMessage {
    for memberId in ["alice", "bob"] {
        try await deliveryService.sendWelcomeMessage(
            groupId: groupId,
            memberId: memberId,
            welcome: welcomeMessage
        )
    }
}
```

## What You Need to Implement 🚀

### 1. Delivery Service (DS)
The Delivery Service is responsible for:
- **Key Package Distribution**: Publishing and retrieving user key packages
- **Message Routing**: Delivering encrypted messages to group members
- **Welcome Message Handling**: Managing group join invitations
- **Group State Synchronization**: Ensuring all members have consistent state

### 2. Server API Design

#### Key Package Management
```
POST   /users/{userId}/key-packages    # Publish key package
GET    /users/{userIds}/key-packages   # Fetch key packages for group creation
DELETE /users/{userId}/key-packages    # Remove expired key packages
```

#### Group Messages
```
POST   /groups/{groupId}/messages      # Send encrypted message
GET    /groups/{groupId}/messages?since={sequence} # Fetch messages since sequence number
```

#### Welcome Messages
```
POST   /groups/{groupId}/welcome/{memberId}  # Send welcome message
GET    /groups/{groupId}/welcome/{memberId}  # Receive welcome message
DELETE /groups/{groupId}/welcome/{memberId}  # Clean up after joining
```

### 3. Communication Flow

#### Group Creation Flow
```swift
// 1. Creator generates key package
let keyPackage = try client.generateKeyPackageMessage()

// 2. Creator publishes key package to server
try await deliveryService.publishKeyPackage(userId: "alice", keyPackage: keyPackage)

// 3. Creator fetches members' key packages
let memberKeyPackages = try await deliveryService.fetchKeyPackages(userIds: ["bob", "charlie"])

// 4. Creator creates group and adds members
let group = try client.createGroup(groupId: nil)
let commitOutput = try group.addMembers(keyPackages: memberKeyPackages)

// 5. Creator sends commit message to all members
try await deliveryService.sendMessage(
    groupId: groupId,
    message: commitOutput.commitMessage,
    senderId: "alice"
)

// 6. Creator sends individual welcome messages
for (index, memberId) in ["bob", "charlie"].enumerated() {
    if let welcomeMessage = commitOutput.welcomeMessages?[index] {
        try await deliveryService.sendWelcomeMessage(
            groupId: groupId,
            memberId: memberId,
            welcome: welcomeMessage
        )
    }
}
```

#### Message Exchange Flow
```swift
// 1. Sender encrypts message
let plaintext = "Hello, team!".data(using: .utf8)!
let encryptedMessage = try group.encryptApplicationMessage(message: plaintext)

// 2. Sender sends to server
try await deliveryService.sendMessage(
    groupId: groupId,
    message: encryptedMessage,
    senderId: "alice"
)

// 3. Recipients fetch new messages
let messages = try await deliveryService.fetchMessages(groupId: groupId, since: lastSequence)

// 4. Recipients decrypt messages
for envelope in messages {
    let message = try Message.fromBytes(bytes: envelope.encryptedMessage)
    let result = try group.processIncomingMessage(message: message)

    switch result {
    case .applicationMessage(let data):
        let content = String(data: data, encoding: .utf8)
        print("Received: \(content ?? "Invalid UTF-8")")
    case .commit:
        try group.writeToStorage() // Update persisted state
    default:
        break
    }
}
```

## Server-Side Implementation

### Database Schema
```sql
-- User key packages
CREATE TABLE user_key_packages (
    user_id VARCHAR PRIMARY KEY,
    key_package_data BLOB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP
);

-- Group messages
CREATE TABLE group_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id VARCHAR NOT NULL,
    sender_id VARCHAR NOT NULL,
    message_type VARCHAR NOT NULL, -- 'application', 'commit', 'proposal'
    encrypted_data BLOB NOT NULL,
    sequence_number BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_group_sequence (group_id, sequence_number)
);

-- Welcome messages
CREATE TABLE welcome_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    group_id VARCHAR NOT NULL,
    member_id VARCHAR NOT NULL,
    welcome_data BLOB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    UNIQUE KEY unique_group_member (group_id, member_id)
);

-- Group membership
CREATE TABLE group_members (
    group_id VARCHAR NOT NULL,
    user_id VARCHAR NOT NULL,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (group_id, user_id)
);
```

### Server Logic

#### Key Package Management
```python
# Store user's key package
def publish_key_package(user_id, key_package_data):
    # Validate user authentication
    # Store key package with expiration
    # Replace any existing key package for user

# Retrieve key packages for group creation
def get_key_packages(user_ids):
    # Fetch key packages for specified users
    # Return in same order as requested
    # Handle missing key packages gracefully
```

#### Message Distribution
```python
# Store encrypted message
def send_message(group_id, sender_id, message_data, message_type):
    # Validate sender is group member
    # Generate sequence number
    # Store message with metadata
    # Notify other group members (optional)

# Retrieve messages for user
def get_messages(group_id, user_id, since_sequence=None):
    # Validate user is group member
    # Return messages since specified sequence
    # Mark messages as delivered (optional)
```

## Client-Side Implementation

### Key Components

#### 1. Delivery Service Client
```swift
protocol MLSDeliveryService {
    func publishKeyPackage(keyPackage: Message) async throws
    func fetchKeyPackages(userIds: [String]) async throws -> [Message]
    func sendMessage(groupId: String, message: Message) async throws
    func fetchMessages(groupId: String, since: Int64) async throws -> [ServerMessage]
    func sendWelcomeMessage(groupId: String, memberId: String, welcome: Message) async throws
    func fetchWelcomeMessage(groupId: String) async throws -> Message?
}
```

#### 2. MLS Manager
```swift
class MLSManager {
    private let deliveryService: MLSDeliveryService
    private let client: Client
    private var groups: [String: Group] = [:]

    // Group management methods
    func createGroup(memberIds: [String]) async throws -> String
    func joinGroup(groupId: String) async throws
    func sendMessage(groupId: String, content: String) async throws
    func syncMessages() async throws
}
```

### Message Processing Flow

#### Receiving Messages
```swift
func processMessages() async throws {
    for groupId in groups.keys {
        let messages = try await deliveryService.fetchMessages(
            groupId: groupId,
            since: getLastSequenceNumber(groupId)
        )

        for serverMessage in messages {
            try await processServerMessage(serverMessage)
            updateLastSequenceNumber(groupId, serverMessage.sequenceNumber)
        }
    }
}

func processServerMessage(_ message: ServerMessage) async throws {
    guard let group = groups[message.groupId] else { return }

    let result = try group.processIncomingMessage(message: message.encryptedMessage)

    switch result {
    case .applicationMessage(let sender, let data):
        handleReceivedMessage(sender: sender, content: data)

    case .commit(let committer, let effect):
        handleGroupUpdate(committer: committer, effect: effect)
        try group.writeToStorage()

    case .receivedProposal(let sender, let proposal):
        handleProposal(sender: sender, proposal: proposal)

    default:
        break
    }
}
```

## Security Considerations

### Authentication & Authorization
- **User Authentication**: Verify user identity before MLS operations
- **Group Membership**: Validate user is member before message access
- **Message Integrity**: Use HTTPS/TLS for all server communications
- **Rate Limiting**: Prevent abuse and spam

### Data Protection
- **Encryption at Rest**: Encrypt stored messages and key packages
- **Access Controls**: Implement proper database permissions
- **Audit Logging**: Log all MLS operations for security monitoring
- **Data Retention**: Implement message expiration and cleanup

### Network Security
- **Certificate Pinning**: Prevent man-in-the-middle attacks
- **Request Signing**: Sign API requests for additional security
- **Replay Protection**: Use timestamps and nonces to prevent replay attacks

## Scalability Considerations

### Database Optimization
- **Indexing**: Index on group_id, sequence_number for efficient queries
- **Partitioning**: Partition large tables by group_id or time
- **Archiving**: Move old messages to archive storage
- **Caching**: Cache frequently accessed key packages

### Message Delivery
- **Push Notifications**: Use WebSocket or push notifications for real-time delivery
- **Batch Processing**: Process multiple messages in batches
- **Queue Management**: Use message queues for reliable delivery
- **Offline Support**: Queue messages when device is offline

### Performance Monitoring
- **Metrics**: Track message throughput, latency, and error rates
- **Alerts**: Set up alerts for performance degradation
- **Load Testing**: Test system under high load conditions
- **Capacity Planning**: Monitor resource usage and plan for growth

## Implementation Examples

### Existing Examples in `/examples/`
The `mls-rs-uniffi/swift/examples/` directory contains working implementations:

- **`ServerIntegrationExample.swift`** - HTTP-based delivery service with base64 encoding
- **`RealmStorageExample.swift`** - Custom Realm-based group state storage
- **`RealmUsageExample.swift`** - Complete usage example with Realm persistence

### Documentation Examples
The examples in `/docs/` are updated to match the actual generated API and serve as:
- **Reference implementations** for common integration patterns
- **API usage examples** with correct method signatures
- **Integration templates** for your specific use cases

### Existing Examples Status
**Note:** Some examples in `/examples/` may use different method names or patterns:
- They might use snake_case (`create_group`) instead of camelCase (`createGroup`)
- They might use different serialization approaches
- Always verify examples against the current generated bindings

**Recommendation:** Use the method names and patterns shown in this guide, as they match the actual generated Swift bindings from UniFFI.

## Implementation Checklist

- [ ] Design REST API endpoints
- [ ] Implement server-side storage and retrieval
- [ ] Create client-side delivery service
- [ ] Handle offline message queuing
- [ ] Implement proper error handling and retries
- [ ] Add authentication and authorization
- [ ] Test with multiple devices and network conditions
- [ ] Implement monitoring and logging
- [ ] Add security measures (encryption, rate limiting)
- [ ] Performance testing and optimization

## Key Takeaways

1. **Separation of Concerns**: MLS wrapper handles crypto, your app handles networking
2. **Delivery Service Pattern**: Abstract server communication behind a protocol
3. **State Synchronization**: Ensure all group members have consistent state
4. **Security First**: Implement proper authentication and encryption
5. **Scalability**: Design for high-throughput message delivery
6. **Error Handling**: Robust error handling for network failures
7. **API Accuracy**: Always use the method names from generated bindings, not examples

This architecture provides a complete, production-ready MLS messaging system that scales from small groups to large-scale deployments.

### 3. Server Communication Flow

#### Key Package Distribution
```swift
class MLSKeyPackageManager {
    private let deliveryService: MLSDeliveryService
    private let client: Client

    func publishCurrentKeyPackage() async throws {
        let keyPackage = try client.generateKeyPackageMessage()

        // Convert to base64 for server transmission
        let keyPackageData = try JSONEncoder().encode(keyPackage)
        let keyPackageB64 = keyPackageData.base64EncodedString()

        try await deliveryService.publishKeyPackage(
            userId: currentUserId,
            keyPackageData: keyPackageB64
        )
    }

    func refreshKeyPackages() async throws {
        // Generate new key package periodically for security
        try await publishCurrentKeyPackage()
    }
}
```

#### Group Creation and Invitation
```swift
class MLSGroupManager {
    private let deliveryService: MLSDeliveryService
    private let client: Client

    func createGroup(name: String, memberIds: [String]) async throws -> String {
        // 1. Create MLS group
        let group = try client.createGroup(groupId: nil)
        let groupId = try generateGroupId()

        // 2. Fetch key packages for members
        let keyPackages = try await deliveryService.fetchKeyPackages(userIds: memberIds)

        // 3. Add members to group
        let commitOutput = try group.addMembers(keyPackages: keyPackages)

        // 4. Send welcome messages to new members
        for (index, memberId) in memberIds.enumerated() {
            if let welcomeMessage = commitOutput.welcome_message {
                try await deliveryService.sendWelcomeMessage(
                    groupId: groupId,
                    memberId: memberId,
                    welcomeMessage: welcomeMessage
                )
            }
        }

        // 5. Send commit message to all members
        try await deliveryService.sendMessage(
            groupId: groupId,
            message: commitOutput.commit_message,
            senderId: currentUserId
        )

        // 6. Store group locally
        try group.writeToStorage()

        return groupId
    }

    func joinGroup(groupId: String, welcomeMessage: Message) async throws {
        let joinInfo = try client.joinGroup(
            ratchetTree: nil,
            welcomeMessage: welcomeMessage
        )

        // Store the joined group
        try joinInfo.group.writeToStorage()

        groups[groupId] = joinInfo.group
    }
}
```

#### Message Sending
```swift
class MLSMessagingManager {
    private let deliveryService: MLSDeliveryService

    func sendMessage(groupId: String, content: String) async throws {
        guard let group = groups[groupId] else {
            throw MLSMessagingError.groupNotFound
        }

        // 1. Encrypt the message
        let messageData = content.data(using: .utf8)!
        let encryptedMessage = try group.encryptApplicationMessage(message: messageData)

        // 2. Send via delivery service
        try await deliveryService.sendMessage(
            groupId: groupId,
            message: encryptedMessage,
            senderId: currentUserId
        )

        // 3. Persist group state
        try group.writeToStorage()
    }
}
```

#### Message Processing
```swift
class MLSMessageProcessor {
    private let deliveryService: MLSDeliveryService

    func processPendingMessages() async throws {
        for groupId in groups.keys {
            let messages = try await deliveryService.fetchMessages(
                groupId: groupId,
                since: lastSyncTimestamp
            )

            for envelope in messages {
                try await processMessage(envelope)
            }
        }
    }

    private func processMessage(_ envelope: MLSMessageEnvelope) async throws {
        guard let group = groups[envelope.groupId] else { return }

        let result = try group.processIncomingMessage(message: envelope.encryptedMessage)

        switch result {
        case .applicationMessage(let sender, let data):
            // Handle decrypted application message
            let content = String(data: Data(data), encoding: .utf8)
            handleReceivedMessage(sender: sender, content: content)

        case .commit(let committer, let effect):
            // Handle group state changes
            handleGroupUpdate(committer: committer, effect: effect)

            // Persist updated group state
            try group.writeToStorage()

        case .receivedProposal(let sender, let proposal):
            // Handle proposals (add/remove members, etc.)
            handleProposal(sender: sender, proposal: proposal)

        default:
            // Handle other message types
            break
        }
    }
}
```

## Server-Side Components

### REST API Endpoints
```swift
// Key Package Management
POST   /users/{userId}/key-packages    // Publish key package
GET    /users/{userIds}/key-packages   // Fetch key packages

// Group Messages
POST   /groups/{groupId}/messages      // Send message
GET    /groups/{groupId}/messages      // Fetch messages

// Welcome Messages
POST   /groups/{groupId}/welcome/{memberId}  // Send welcome
GET    /groups/{groupId}/welcome/{memberId}  // Receive welcome
```

### Database Schema
```sql
-- Key Packages Table
CREATE TABLE key_packages (
    user_id VARCHAR PRIMARY KEY,
    key_package_data BLOB,
    created_at TIMESTAMP,
    expires_at TIMESTAMP
);

-- Group Messages Table
CREATE TABLE group_messages (
    id UUID PRIMARY KEY,
    group_id VARCHAR,
    sender_id VARCHAR,
    message_type VARCHAR,
    encrypted_data BLOB,
    sequence_number BIGINT,
    created_at TIMESTAMP
);

-- Group Membership Table
CREATE TABLE group_members (
    group_id VARCHAR,
    user_id VARCHAR,
    joined_at TIMESTAMP,
    PRIMARY KEY (group_id, user_id)
);
```

## Complete Communication Flow

### 1. User Registration
```
Client → Server: Publish key package
Server → Database: Store key package
```

### 2. Group Creation
```
Creator:
  1. Create MLS group
  2. Fetch members' key packages
  3. Add members (creates commit + welcome messages)
  4. Send commit to all members
  5. Send individual welcome messages

Members:
  1. Receive welcome message
  2. Join group using welcome message
  3. Receive and process commit message
```

### 3. Message Exchange
```
Sender:
  1. Encrypt message with group
  2. Send to server
  3. Update local group state

Recipients:
  1. Fetch messages from server
  2. Decrypt using group
  3. Update local group state
  4. Process any commits/proposals
```

## Security Considerations

### Message Ordering
- Use sequence numbers to ensure message ordering
- Handle out-of-order message delivery
- Implement message deduplication

### Authentication
- Authenticate users before allowing message operations
- Validate group membership before processing messages
- Use HTTPS/TLS for all server communications

### Rate Limiting
- Implement rate limits on message sending
- Prevent spam and abuse
- Monitor for suspicious activity patterns

### Data Privacy
- Encrypt data at rest in the database
- Implement proper access controls
- Regular security audits and penetration testing

## Implementation Checklist

- [ ] Design Delivery Service API
- [ ] Implement server-side message storage
- [ ] Create client-side message synchronization
- [ ] Handle offline message queuing
- [ ] Implement proper error handling and retries
- [ ] Add comprehensive logging and monitoring
- [ ] Test with multiple devices and network conditions
- [ ] Implement backup and recovery mechanisms

This architecture provides a complete MLS messaging system where the UniFFI wrapper handles all cryptographic operations while your application layer manages server communication and message distribution.
