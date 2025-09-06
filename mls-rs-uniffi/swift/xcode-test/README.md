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
- Client tests (creation, identity, multiple cipher suites)
- Group tests (creation, membership, proposals, persistence)
- Encryption tests (basic, bidirectional, multiple messages, large messages)

## Prerequisites

- **Xcode Command Line Tools**: `xcode-select --install`
- **Generated Swift Bindings**: Run `../generate_swift_bindings.sh` first
- **Compiled MLS Library**: The debug `.dylib` file must exist

## How It Works

The test scripts:

1. **Check Prerequisites**: Verify Swift compiler and required files exist
2. **Auto-Generate Bindings**: Run the generation script if bindings are missing
3. **Create Temporary Environment**: Copy bindings and library to temp directory
4. **Compile Test Program**: Use `swiftc` with proper FFI headers and linking
5. **Run Tests**: Execute the compiled test program
6. **Report Results**: Show pass/fail status and cleanup

## Integration Notes

These tests demonstrate the correct way to:

- **Import the MLS module** in Swift projects
- **Link against the dynamic library** (`.dylib`)
- **Configure FFI headers** and module maps
- **Handle MLS errors** in Swift
- **Use the MLS API** from Swift code

## Known Issues

- The MLS bindings define an `Error` enum that can conflict with Swift's built-in `Error` protocol
- Some type names may need qualification (e.g., `MLS.Error` vs `Swift.Error`)
- Library paths must be configured correctly for runtime linking

## Troubleshooting

### "Cannot find 'clientConfigDefault' in scope"
- Ensure the Swift bindings are generated and included in compilation

### "Dynamic library not found"
- Run the binding generation script first: `../generate_swift_bindings.sh`

### "Swift compiler not found"
- Install Xcode command line tools: `xcode-select --install`

### Linking errors
- Verify the `.dylib` path is correct for your target architecture
- Check that `DYLD_LIBRARY_PATH` includes the library directory

## Next Steps

After successful tests:

1. **Copy generated bindings** to your Xcode project
2. **Configure build settings** to include the library and headers
3. **Set up proper module imports** in your Swift files
4. **Handle library distribution** for your app bundle

For detailed integration instructions, see the main `swift/README.md` file.
