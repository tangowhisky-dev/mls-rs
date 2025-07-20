# MLS-RS Swift API Reference

Complete reference for the MLS-RS Swift bindings public API. This document covers all public types, protocols, functions, and enums available to Swift developers.

## Table of Contents

1. [Top-Level Functions](#top-level-functions)
2. [Core Protocols](#core-protocols)
3. [Core Classes](#core-classes)
4. [Data Types](#data-types)
5. [Enumerations](#enumerations)
6. [Error Handling](#error-handling)

## Top-Level Functions

### generateSignatureKeypair(cipherSuite:)
```swift
public func generateSignatureKeypair(cipherSuite: CipherSuite) throws -> SignatureKeypair
```
Generate a MLS signature keypair using the default crypto provider.

**Parameters:**
- `cipherSuite`: The cipher suite to use for key generation

**Returns:** A `SignatureKeypair` containing the public and private keys

**Throws:** MLS errors if key generation fails

**Example:**
```swift
let keypair = try generateSignatureKeypair(cipherSuite: .MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519)
```

### clientConfigDefault()
```swift
public func clientConfigDefault() -> ClientConfig
```
Create a client configuration with in-memory group state storage and default settings.

**Returns:** A `ClientConfig` with default configuration

**Example:**
```swift
let config = clientConfigDefault()
```

## Core Protocols

### ClientProtocol
The main protocol for MLS client operations.

#### Methods

##### createGroup(groupId:extensions:)
```swift
func createGroup(groupId: Data, extensions: ExtensionList) throws -> Group
```
Create a new MLS group.

**Parameters:**
- `groupId`: Unique identifier for the group
- `extensions`: List of extensions to include

**Returns:** A new `Group` instance

##### generateKeyPackageMessage()
```swift
func generateKeyPackageMessage() throws -> Message
```
Generate a key package message for joining groups.

**Returns:** A `Message` containing the key package

##### joinGroup(welcome:ratchetTree:)
```swift
func joinGroup(welcome: Message, ratchetTree: RatchetTree?) throws -> Group
```
Join an existing group using a welcome message.

**Parameters:**
- `welcome`: Welcome message from group admin
- `ratchetTree`: Optional ratchet tree for the group

**Returns:** The joined `Group` instance

##### loadGroup(groupId:)
```swift
func loadGroup(groupId: Data) throws -> Group
```
Load a previously created or joined group from storage.

**Parameters:**
- `groupId`: Identifier of the group to load

**Returns:** The loaded `Group` instance

##### signingIdentity()
```swift
func signingIdentity() throws -> SigningIdentity
```
Get the signing identity of this client.

**Returns:** The client's `SigningIdentity`

### GroupProtocol
Protocol for MLS group operations.

#### Methods

##### addMembers(keyPackages:)
```swift
func addMembers(keyPackages: [Message]) throws -> CommitOutput
```
Commit the addition of new members to the group.

**Parameters:**
- `keyPackages`: Array of key package messages for new members

**Returns:** `CommitOutput` containing commit message and welcome messages

##### commit()
```swift
func commit() throws -> CommitOutput
```
Perform a commit of received proposals or an empty commit.

**Returns:** `CommitOutput` with the commit message

##### encryptApplicationMessage(message:)
```swift
func encryptApplicationMessage(message: Data) throws -> Message
```
Encrypt an application message for the group.

**Parameters:**
- `message`: Raw application data to encrypt

**Returns:** Encrypted `Message` to send to group members

##### exportTree()
```swift
func exportTree() throws -> RatchetTree
```
Export the current epoch's ratchet tree.

**Returns:** Serialized `RatchetTree`

##### processIncomingMessage(message:)
```swift
func processIncomingMessage(message: Message) throws -> ReceivedMessage
```
Process an incoming message for this group.

**Parameters:**
- `message`: Incoming MLS message

**Returns:** `ReceivedMessage` with processed content

##### proposeAddMembers(keyPackages:)
```swift
func proposeAddMembers(keyPackages: [Message]) throws -> [Message]
```
Propose adding new members without committing.

**Parameters:**
- `keyPackages`: Key packages for proposed members

**Returns:** Array of proposal messages

##### proposeRemoveMembers(signingIdentities:)
```swift
func proposeRemoveMembers(signingIdentities: [SigningIdentity]) throws -> [Message]
```
Propose removing members without committing.

**Parameters:**
- `signingIdentities`: Identities of members to remove

**Returns:** Array of proposal messages

##### removeMembers(signingIdentities:)
```swift
func removeMembers(signingIdentities: [SigningIdentity]) throws -> CommitOutput
```
Propose and commit removal of members.

**Parameters:**
- `signingIdentities`: Identities of members to remove

**Returns:** `CommitOutput` with the commit message

##### writeToStorage()
```swift
func writeToStorage() throws
```
Write the current group state to configured storage.

### GroupStateStorageProtocol
Protocol for custom group state storage implementations.

#### Methods

##### state()
```swift
func state() throws -> Data
```
Get the current state data.

##### epoch()
```swift
func epoch() throws -> UInt64
```
Get the current epoch number.

##### write(epochId:groupState:)
```swift
func write(epochId: UInt64, groupState: Data) throws
```
Write group state for a specific epoch.

##### maxEpochId()
```swift
func maxEpochId() throws -> UInt64?
```
Get the maximum epoch ID stored.

## Core Classes

### Client
```swift
open class Client: ClientProtocol
```
Main MLS client implementation for creating and managing groups.

#### Initializer

##### init(signingKeypair:config:)
```swift
public init(signingKeypair: SignatureKeypair, config: ClientConfig) throws
```
Create a new MLS client.

**Parameters:**
- `signingKeypair`: Client's signature keypair
- `config`: Client configuration

### Group
```swift
open class Group: GroupProtocol
```
MLS group implementation for encrypted messaging and member management.

### Message
```swift
open class Message
```
Represents MLS protocol messages (proposals, commits, application messages, etc.).

### Extension
```swift
open class Extension
```
Represents MLS protocol extensions.

### ExtensionList
```swift
open class ExtensionList
```
Collection of MLS extensions.

### Proposal
```swift
open class Proposal
```
Represents MLS proposals (add, remove, update, etc.).

### SigningIdentity
```swift
open class SigningIdentity
```
Represents a member's signing identity in MLS.

### GroupStateStorage
```swift
open class GroupStateStorage: GroupStateStorageProtocol
```
Base class for group state storage implementations.

## Data Types

### ClientConfig
```swift
public struct ClientConfig
```
Configuration for MLS client behavior and storage.

**Properties:**
- Group state storage configuration
- Crypto provider settings
- Protocol version preferences
- Extension configurations

### CommitOutput
```swift
public struct CommitOutput
```
Result of a commit operation.

**Properties:**
- `commitMessage`: The commit message to send
- `welcomeMessages`: Welcome messages for new members (if any)
- `groupInfo`: Updated group information

### SignatureKeypair
```swift
public struct SignatureKeypair
```
A signature key pair for MLS operations.

**Properties:**
- `publicKey`: Public key data
- `privateKey`: Private key data

### RatchetTree
```swift
public struct RatchetTree
```
Serialized representation of the group's ratchet tree.

### EpochRecord
```swift
public struct EpochRecord
```
Record of a specific epoch's state and metadata.

## Enumerations

### CipherSuite
```swift
public enum CipherSuite
```
Supported MLS cipher suites.

**Cases:**
- `.MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519` - X25519 + AES-128-GCM + SHA-256 + Ed25519
- `.MLS_128_DHKEMP256_AES128GCM_SHA256_P256` - P-256 + AES-128-GCM + SHA-256 + ECDSA P-256
- `.MLS_128_DHKEMX25519_CHACHA20POLY1305_SHA256_Ed25519` - X25519 + ChaCha20Poly1305 + SHA-256 + Ed25519
- `.MLS_256_DHKEMX448_AES256GCM_SHA512_Ed448` - X448 + AES-256-GCM + SHA-512 + Ed448
- `.MLS_256_DHKEMP521_AES256GCM_SHA512_P521` - P-521 + AES-256-GCM + SHA-512 + ECDSA P-521

### ProtocolVersion
```swift
public enum ProtocolVersion
```
Supported MLS protocol versions.

**Cases:**
- `.MLS_1_0` - MLS Protocol Version 1.0

### ReceivedMessage
```swift
public enum ReceivedMessage
```
Types of messages that can be received and processed.

**Cases:**
- `.ApplicationMessage(Data)` - Decrypted application message
- `.Commit(CommitOutput)` - Processed commit with effects
- `.Proposal(Proposal)` - Received proposal

### CommitEffect
```swift
public enum CommitEffect
```
Effects of processing a commit message.

**Cases:**
- `.MemberAdded` - New member was added
- `.MemberRemoved` - Member was removed
- `.MemberUpdated` - Member updated their key
- `.GroupUpdated` - Group metadata updated

### MlsError
```swift
public enum MlsError: Error
```
MLS-specific errors.

**Cases:**
- `.InvalidMessage` - Invalid MLS message format
- `.UnknownMember` - Member not found in group
- `.InvalidSignature` - Signature verification failed
- `.CryptoError` - Cryptographic operation failed
- `.StorageError` - Storage operation failed
- `.ConfigurationError` - Invalid configuration
- And many more specific error types...

## Error Handling

All MLS operations that can fail throw Swift errors. Most errors are of type `MlsError` which provides detailed information about what went wrong.

### Common Error Patterns

```swift
do {
    let group = try client.createGroup(groupId: groupId, extensions: extensions)
    // Success
} catch MlsError.InvalidMessage {
    // Handle invalid message
} catch MlsError.CryptoError {
    // Handle crypto failure
} catch {
    // Handle other errors
}
```

### Best Practices

1. **Always handle errors** - MLS operations can fail for various reasons
2. **Check error types** - Different errors may require different handling
3. **Log errors appropriately** - Helps with debugging and monitoring
4. **Graceful degradation** - Have fallback strategies for critical errors

## Usage Examples

### Basic Client Setup
```swift
import MlsRs

// Generate client keypair
let keypair = try generateSignatureKeypair(cipherSuite: .MLS_128_DHKEMX25519_AES128GCM_SHA256_Ed25519)

// Create client with default config
let config = clientConfigDefault()
let client = try Client(signingKeypair: keypair, config: config)
```

### Creating and Joining Groups
```swift
// Create a new group
let groupId = "my-group".data(using: .utf8)!
let extensions = ExtensionList() // Empty extensions list
let group = try client.createGroup(groupId: groupId, extensions: extensions)

// Generate key package for others to add you
let keyPackage = try client.generateKeyPackageMessage()

// Join an existing group (when invited)
let joinedGroup = try client.joinGroup(welcome: welcomeMessage, ratchetTree: nil)
```

### Sending Messages
```swift
// Encrypt and send application message
let messageData = "Hello, group!".data(using: .utf8)!
let encryptedMessage = try group.encryptApplicationMessage(message: messageData)
// Send encryptedMessage to all group members
```

### Processing Incoming Messages
```swift
// Process received message
let receivedMessage = try group.processIncomingMessage(message: incomingMessage)

switch receivedMessage {
case .ApplicationMessage(let data):
    let text = String(data: data, encoding: .utf8)
    print("Received: \(text ?? "invalid text")")
    
case .Commit(let commitOutput):
    print("Group state updated")
    
case .Proposal(let proposal):
    print("Received proposal")
}
```

This API reference provides complete coverage of the MLS-RS Swift bindings public interface. For implementation details and examples, refer to the other documentation files in this repository.
