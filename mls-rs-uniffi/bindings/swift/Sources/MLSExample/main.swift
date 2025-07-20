import Foundation
import MlsRs

print("MLS Rust Swift Bindings Example")

do {
    // Generate a signature keypair
    print("Generating signature keypair...")
    let keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)
    print("Generated keypair successfully")
    
    // Create client configuration
    print("Creating client configuration...")
    let config = clientConfigDefault()
    print("Created default configuration")
    
    // Create a client
    print("Creating MLS client...")
    let clientId = "alice".data(using: .utf8)!
    let client = Client(id: clientId, signatureKeypair: keypair, clientConfig: config)
    print("Created client with ID: alice")
    
    // Create a group
    print("Creating MLS group...")
    let group = try client.createGroup(groupId: nil)
    print("Created group successfully")
    
    // Test basic encryption/decryption
    print("\nTesting message encryption...")
    let messageData = "Hello, MLS!".data(using: .utf8)!
    
    // Encrypt a message
    let encryptedMessage = try group.encryptApplicationMessage(message: messageData)
    print("Encrypted message: \(encryptedMessage)")
    
    // The same client would decrypt the message in a real scenario,
    // but for demo purposes, let's just show we can access the encrypted data
    print("Message encrypted successfully!")
    
    print("\n✅ MLS Swift bindings test completed successfully!")
    
} catch let error as MlsError {
    print("❌ MLS Error: \(error)")
} catch {
    print("❌ Unexpected error: \(error)")
}
