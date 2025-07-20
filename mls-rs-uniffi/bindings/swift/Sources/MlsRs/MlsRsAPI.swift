import Foundation

// MARK: - MLS-RS Swift Bindings API Documentation

/**
 * MLS-RS Swift Bindings
 *
 * This module provides Swift bindings for the MLS-RS (Messaging Layer Security - Rust) library,
 * enabling secure group messaging with forward secrecy and post-compromise security.
 *
 * ## Key Classes
 *
 * - `Client`: Main interface for creating and managing MLS groups
 * - `Group`: Represents an MLS group for secure messaging
 * - `GroupStateStorage`: Protocol for persisting group state
 * - `SwiftDataStorage`: SwiftData implementation of group state storage
 * - `Message`: MLS protocol messages
 * - `Extension`: MLS extensions for additional functionality
 *
 * ## Usage
 *
 * ```swift
 * // Create a client
 * let client = try Client(
 *     id: "user123".data(using: .utf8)!,
 *     signatureKeypair: signatureKeypair,
 *     clientConfig: config
 * )
 *
 * // Create a group
 * let group = try client.createGroup(groupId: nil)
 *
 * // Send a message
 * try group.sendMessage(applicationMessage: messageData)
 * ```
 */

// Re-export the main Client type for better documentation
/**
 * An MLS client used to create key packages and manage groups.
 *
 * The Client is the main entry point for MLS operations. It manages
 * cryptographic keys, creates and joins groups, and handles the MLS
 * protocol state.
 *
 * ## Creating a Client
 *
 * ```swift
 * let client = try Client(
 *     id: userIdentifier,
 *     signatureKeypair: keypair,
 *     clientConfig: configuration
 * )
 * ```
 *
 * ## Key Operations
 *
 * - Create new groups with `createGroup(groupId:)`
 * - Join existing groups with `joinGroup(ratchetTree:welcomeMessage:)`
 * - Load existing groups with `loadGroup(groupId:)`
 * - Generate key packages with `generateKeyPackageMessage()`
 */
public typealias MLSClient = Client

/**
 * Represents an MLS group for secure messaging.
 *
 * A Group handles all messaging operations within an MLS group,
 * including sending messages, adding/removing members, and managing
 * group state transitions.
 *
 * ## Messaging
 *
 * ```swift
 * // Send an application message
 * try group.sendMessage(applicationMessage: data)
 *
 * // Process received messages
 * let result = try group.processMessage(message: receivedMessage)
 * ```
 *
 * ## Member Management
 *
 * ```swift
 * // Add a new member
 * try group.addMembers(keyPackages: [newMemberKeyPackage])
 *
 * // Remove a member
 * try group.removeMembers(membersToRemove: [memberIndex])
 * ```
 */
public typealias MLSGroup = Group

/**
 * Protocol for storing and retrieving MLS group state.
 *
 * Implement this protocol to provide custom storage for MLS group state.
 * The library includes a SwiftData implementation (`SwiftDataStorage`).
 *
 * ## Storage Requirements
 *
 * The storage must be able to:
 * - Store and retrieve current group state
 * - Store and retrieve historical epoch data
 * - Handle concurrent access safely
 * - Persist data across app restarts
 */
public typealias MLSGroupStateStorage = GroupStateStorage

/**
 * Represents an MLS protocol message.
 *
 * Messages are the fundamental unit of communication in MLS.
 * They can be application messages (encrypted content) or
 * protocol messages (group management operations).
 *
 * ## Message Types
 *
 * - Application messages: Encrypted user content
 * - Handshake messages: Group state changes (add/remove members, etc.)
 * - Welcome messages: Invitation to join a group
 * - Key package messages: Public key material for joining groups
 */
public typealias MLSMessage = Message

/**
 * MLS extension for adding custom functionality.
 *
 * Extensions allow applications to add custom data and behavior
 * to MLS groups while maintaining security properties.
 */
public typealias MLSExtension = Extension

/**
 * Collection of MLS extensions.
 *
 * Manages multiple extensions in a single container,
 * providing efficient access and iteration.
 */
public typealias MLSExtensionList = ExtensionList

/**
 * MLS proposal for group state changes.
 *
 * Proposals represent pending changes to the group state,
 * such as adding or removing members, updating keys, or
 * modifying group configuration.
 */
public typealias MLSProposal = Proposal
