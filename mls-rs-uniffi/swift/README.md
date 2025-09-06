# MLS Swift Bindings

This directory contains Swift language bindings for the mls-rs library, generated using UniFFI.

## Structure

```
swift/
├── Package.swift           # Swift Package Manager configuration
├── bindings/              # Generated Swift bindings
│   ├── mls_rs_uniffi.swift      # Main Swift API
│   ├── mls_rs_uniffiFFI.h       # C header file
│   └── mls_rs_uniffiFFI.modulemap # Module map
├── tests/                 # Swift unit tests
│   └── MLSSwiftTests.swift
├── examples/              # Example Swift code (TODO)
└── docs/                  # Documentation (TODO)
```

## Building

### Prerequisites

- Xcode 15.0+ or Swift 5.9+
- Rust toolchain with the required target
- The compiled mls-rs-uniffi dynamic library

### Generate Bindings

From the mls-rs-uniffi directory, run:

```bash
./generate_swift_bindings.sh
```

This will:
1. Build the Rust library for macOS
2. Generate Swift bindings using UniFFI
3. Place the generated files in `swift/bindings/`

### Run Tests

Navigate to the swift directory and run:

```bash
cd swift
swift test
```

Note: You may need to adjust the library path in your project configuration to point to the compiled `.dylib` file.

## Usage

### Basic Example

```swift
import Foundation
// Import your MLS bindings module

// Create a client configuration
let clientConfig = clientConfigDefault()

// Generate a signature keypair
let keypair = try generateSignatureKeypair(cipherSuite: .curve25519Aes128)

// Create a client
let clientId = "alice".data(using: .utf8)!
let alice = Client(id: clientId, signatureKeypair: keypair, clientConfig: clientConfig)

// Create a group
let group = try alice.createGroup(groupId: nil)

// Save to storage
try group.writeToStorage()
```

### Adding Members to a Group

```swift
// Alice creates a group
let aliceGroup = try alice.createGroup(groupId: nil)

// Bob generates a key package
let bobKeyPackage = try bob.generateKeyPackageMessage()

// Alice adds Bob to the group
let commitResult = try aliceGroup.addMembers(keyPackages: [bobKeyPackage])

// Alice processes the commit
_ = try aliceGroup.processIncomingMessage(message: commitResult.commitMessage)

// Bob joins using the welcome message
let joinInfo = try bob.joinGroup(ratchetTree: nil, welcomeMessage: commitResult.welcomeMessage)
let bobGroup = joinInfo.group
```

### Encrypting and Decrypting Messages

```swift
// Alice encrypts a message
let plaintext = "Hello, Bob!".data(using: .utf8)!
let encryptedMessage = try aliceGroup.encryptApplicationMessage(applicationData: plaintext)

// Bob decrypts the message
let decryptResult = try bobGroup.processIncomingMessage(message: encryptedMessage)

switch decryptResult {
case .applicationMessage(let data):
    print("Received: \\(String(data: data, encoding: .utf8) ?? "Invalid UTF-8")")
default:
    print("Received non-application message")
}
```

## Supported Cipher Suites

The following cipher suites are supported:

- `.curve25519Aes128`
- `.p256Aes128`
- `.curve25519Aes256`
- `.p256Aes256`
- `.curve25519Chacha20Poly1305`
- `.p384Aes256`
- `.p521Aes256`
- `.curve448Aes256`
- `.curve448Chacha20Poly1305`

## Error Handling

All MLS operations that can fail throw Swift errors. Make sure to wrap calls in `try` blocks:

```swift
do {
    let group = try alice.createGroup(groupId: nil)
    try group.writeToStorage()
} catch {
    print("MLS operation failed: \\(error)")
}
```

## Integration in iOS/macOS Projects

### Using Swift Package Manager

Add this to your `Package.swift`:

```swift
dependencies: [
    .package(path: "path/to/mls-rs-uniffi/swift")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["MLSSwiftBindings"]
    )
]
```

### Using Xcode

1. Drag the `swift` folder into your Xcode project
2. Make sure the `.dylib` file is included in your app bundle
3. Import the module in your Swift files

## Threading and Async Support

The current bindings are synchronous. For async support in Swift, you can wrap the calls:

```swift
func createGroupAsync() async throws -> Group {
    return try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global().async {
            do {
                let group = try alice.createGroup(groupId: nil)
                continuation.resume(returning: group)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

## Known Issues

- The bindings currently use synchronous APIs only
- Memory management is handled automatically, but be aware of retain cycles
- Error messages may not be as detailed as the Rust equivalents

## Contributing

When adding new tests or examples:

1. Add tests to `tests/MLSSwiftTests.swift`
2. Add examples to `examples/` (create files as needed)
3. Update this README with new usage patterns
4. Ensure all tests pass with `swift test`
