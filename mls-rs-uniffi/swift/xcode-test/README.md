# MLS Swift Bindings - Xcode Command Line Tests

This directory contains Xcode command line tools for testing the MLS Swift bindings, similar to the vodozemac project structure.

## Structure

```
xcode-test/
├── run_xcode_test.sh       # Main test script (comprehensive)
├── test_simple.sh          # Simple validation script  
├── main.swift              # Main test program
├── client_tests.swift      # Client-related tests
├── group_tests.swift       # Group management tests
├── encryption_tests.swift  # Message encryption tests
└── README.md              # This file
```

## Purpose

These tests provide:

1. **Quick validation** that the Swift bindings work with Xcode tools
2. **Command-line testing** without needing a full Xcode project
3. **Integration verification** that FFI, library linking, and Swift compilation work together
4. **Reference implementation** for developers integrating MLS into iOS/macOS projects

## Usage

### Simple Test (Quick Validation)

```bash
./test_simple.sh
```

This runs a basic test to verify:
- Client configuration creation
- Signature keypair generation  
- Client instantiation
- Group creation

### Comprehensive Test (Full Validation)

```bash
./run_xcode_test.sh
```

This runs the full test suite including:
- **Client tests**: Creation, identity, all 7 cipher suites
- **Group tests**: Creation, membership, proposals, persistence
- **Encryption tests**: Basic, bidirectional, multiple messages, large messages
- **Advanced API tests**: Tree export, member operations, group state
- **Error handling tests**: Invalid operations, storage APIs
- **GroupStateStorage tests**: State access, epoch management, write operations
- **Comprehensive API tests**: Remove/add members, persistence with load, ReceivedMessage types
- **Cipher suite analysis**: Complete analysis of all 7 standard MLS cipher suites
- **P521 enterprise tests**: High-security cipher suite validation
- **All cipher suites test**: Validates all 7 cipher suites work correctly
- **Enterprise categories**: Tests enterprise, mobile, and high-security cipher suite groups
- **Interoperability tests**: Cross-cipher-suite compatibility

### Cipher Suite Selection

The comprehensive test supports cipher suite selection via command-line argument:

```bash
# Test with specific cipher suite ID (default: 1)
./run_xcode_test.sh 1   # curve25519Aes128
./run_xcode_test.sh 2   # p256Aes128
./run_xcode_test.sh 3   # curve25519Chacha
./run_xcode_test.sh 4   # curve448Aes256
./run_xcode_test.sh 5   # p521Aes256
./run_xcode_test.sh 6   # curve448Chacha
./run_xcode_test.sh 7   # p384Aes256

# Test all cipher suites sequentially
for id in 1 2 3 4 5 6 7; do
    echo "Testing cipher suite ID $id..."
    ./run_xcode_test.sh "$id"
done
```

### Release Mode Testing

Both debug and release versions of the library can be tested:

```bash
# Test with debug library (default)
./run_xcode_test.sh 1

# Test with optimized release library
./run_xcode_test.sh 1 --release
./run_xcode_test.sh --release 1   # Both orders work

# Test specific cipher suite with release library
./run_xcode_test.sh 2 --release   # p256Aes128 with release library
./run_xcode_test.sh --release 5   # p521Aes256 with release library

# Test all cipher suites with release library
for id in 1 2 3 4 5 6 7; do
    echo "Testing cipher suite ID $id with release library..."
    ./run_xcode_test.sh "$id" --release
done
```

### Performance Comparison

The `--release` flag uses an optimized library build:
- **Release library**: ~2.5MB, optimized performance, no debug symbols
- **Debug library**: ~8.4MB, unoptimized, includes debug symbols
- **Use cases**: Release mode for production testing, debug mode for development

## Supported Cipher Suites

The MLS Swift bindings now support **all 7 standard MLS cipher suites**:

| Cipher Suite | Swift Enum | MLS ID | Use Case |
|-------------|------------|---------|----------|
| `curve25519Aes128` | `CipherSuite.curve25519Aes128` | 1 | Baseline standard |
| `p256Aes128` | `CipherSuite.p256Aes128` | 2 | Enterprise standard |
| `curve25519Chacha` | `CipherSuite.curve25519Chacha` | 3 | Mobile optimized |
| `curve448Aes256` | `CipherSuite.curve448Aes256` | 4 | High security |
| `p521Aes256` | `CipherSuite.p521Aes256` | 5 | Maximum security |
| `curve448Chacha` | `CipherSuite.curve448Chacha` | 6 | High security mobile |
| `p384Aes256` | `CipherSuite.p384Aes256` | 7 | Government standard |

## Test Results

The comprehensive test suite runs **15 different test categories** and validates:

- ✅ **All 7 standard MLS cipher suites** work correctly
- ✅ **Client creation and management** across all cipher suites  
- ✅ **Group operations** (create, join, add/remove members)
- ✅ **Message encryption/decryption** with bidirectional messaging
- ✅ **Advanced APIs** (tree export, member operations, group state)
- ✅ **Error handling** and storage operations
- ✅ **Enterprise scenarios** with high-security cipher suites
- ✅ **Mobile optimization** with ChaCha20 cipher suites
- ✅ **Cross-cipher-suite compatibility**

Expected output: **15/15 tests passed** with comprehensive validation across all cipher suites.

## Prerequisites

- **Xcode Command Line Tools**: `xcode-select --install`
- **Generated Swift Bindings**: Run `../generate_swift_bindings.sh [--release]` first
- **Compiled MLS Library**: The debug or release `.dylib` file must exist

## How It Works

The test scripts:

1. **Check Prerequisites**: Verify Swift compiler and required files exist
2. **Auto-Generate Bindings**: Run the generation script if bindings are missing (with Error fix applied, respects --release flag)
3. **Create Temporary Environment**: Copy fixed bindings and library to temp directory  
4. **Compile Test Program**: Use `swiftc` with proper FFI headers and linking
5. **Run Comprehensive Tests**: Execute 15 test categories with selected cipher suite
6. **Report Results**: Show detailed pass/fail status and cleanup

## Integration Notes

These tests demonstrate the correct way to:

- **Import the MLS module** in Swift projects
- **Link against the dynamic library** (`.dylib`)
- **Configure FFI headers** and module maps
- **Handle MLS errors** in Swift
- **Use the MLS API** from Swift code

## Known Issues

- ✅ **RESOLVED**: The MLS bindings previously defined an `Error` enum that conflicted with Swift's built-in `Error` protocol
  - **Fix applied**: The generation script now automatically fixes this conflict
  - **Location**: Fixed in `generate_swift_bindings.sh` with sed commands
- Library paths must be configured correctly for runtime linking on target devices
- Some advanced APIs may require additional configuration for production use

## Troubleshooting

### "Cannot find 'clientConfigDefault' in scope"
- Ensure the Swift bindings are generated: `../generate_swift_bindings.sh`
- Verify the bindings include all required APIs

### "Dynamic library not found"  
- Run: `../generate_swift_bindings.sh` to generate bindings and copy library
- For release mode: `../generate_swift_bindings.sh --release`
- Check that the `.dylib` file exists in the bindings directory

### "Swift compiler not found"
- Install Xcode command line tools: `xcode-select --install`
- Verify installation: `swift --version`

### Linking errors
- Verify the `.dylib` path is correct for your target architecture (arm64 for Apple Silicon)
- Check that the library was built for the correct target: `file path/to/libmls_rs_uniffi.dylib`

### Cipher suite errors
- Ensure you're using the correct cipher suite enum values
- Valid options: `curve25519Aes128`, `p256Aes128`, `curve25519Chacha`, `curve448Aes256`, `p521Aes256`, `curve448Chacha`, `p384Aes256`

### Performance testing
- Use `--release` flag for performance testing with optimized library
- Debug mode (default) includes symbols and is larger but easier to debug
- Release mode is ~70% smaller and optimized for production-like testing

## Next Steps

After successful tests:

1. **Copy generated bindings** to your Xcode project from `../swift/bindings/`
2. **Choose appropriate cipher suite** for your use case:
   - **Enterprise**: `p256Aes128`, `p384Aes256`, `p521Aes256`  
   - **Mobile**: `curve25519Chacha`, `curve448Chacha`
   - **Baseline**: `curve25519Aes128`
   - **High Security**: `curve448Aes256`, `p521Aes256`
3. **Configure build settings** to include the library and headers
4. **Set up proper module imports** in your Swift files
5. **Handle library distribution** for your app bundle
6. **Test with your chosen cipher suite** using the validated APIs

For detailed integration instructions, see the main `swift/README.md` file.
