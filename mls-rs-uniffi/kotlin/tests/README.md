# MLS Kotlin Bindings Tests

This directory contains comprehensive tests for the MLS (Messaging Layer Security) Kotlin bindings generated via UniFFI.

## Quick Start

```bash
# Generate Kotlin bindings and run tests (debug mode)
./run_kotlin_tests.sh

# Generate Kotlin bindings and run tests (release mode)
./run_kotlin_tests.sh --release

# Test specific cipher suite (debug mode)
./run_kotlin_tests.sh 2  # P-256 AES-128 (enterprise)

# Test specific cipher suite (release mode)
./run_kotlin_tests.sh --release 5  # P-521 AES-256 (maximum security)
```

## Prerequisites

- **Kotlin**: Version 2.0.20+ (Kotlin/JVM)
- **Gradle**: For build management
- **JDK**: Java 22+ (compatible JVM)
- **Rust**: For generating native bindings
- **UniFFI**: For Kotlin bindings generation

## Project Structure

```
kotlin/tests/
├── build.gradle.kts          # Gradle build configuration
├── run_kotlin_tests.sh       # Automated test runner
├── README.md                 # This file
└── src/
    ├── main/
    │   ├── kotlin/            # Generated bindings (copied from ../bindings/)
    │   └── resources/         # Native libraries (.dylib files)
    └── test/kotlin/
        ├── BasicLoadTest.kt   # Basic library loading and cipher suite tests
        ├── MLSAPITest.kt      # Comprehensive API testing
        └── MLSComprehensiveTest.kt  # Full workflow tests with cipher suite selection
```

## Available Tests

### 1. BasicLoadTest
- **Purpose**: Verify library loading and basic functionality
- **Tests**: Library loading, cipher suite creation
- **Runtime**: Fast (~1-2 seconds)

### 2. MLSAPITest
- **Purpose**: Comprehensive API validation
- **Tests**: Client configuration, signature keypair generation, client creation, group creation, all cipher suites, error handling
- **Runtime**: Medium (~5-10 seconds)

### 3. MLSComprehensiveTest
- **Purpose**: Full MLS workflow validation with cipher suite selection
- **Tests**: Complete client and group lifecycle, encryption tests, persistence
- **Runtime**: Longer (~10-20 seconds)
- **Features**: Supports cipher suite selection via system property

## Cipher Suite Support

The tests support all 7 standard MLS cipher suites:

| ID | Cipher Suite | Description |
|----|--------------|-------------|
| 1 | Curve25519 AES-128 | Baseline (default) |
| 2 | P-256 AES-128 | Enterprise |
| 3 | Curve25519 ChaCha | Mobile optimized |
| 4 | Curve448 AES-256 | High security |
| 5 | P-521 AES-256 | Maximum security |
| 6 | Curve448 ChaCha | High security mobile |
| 7 | P-384 AES-256 | Government standard |

## Usage Examples

### Basic Testing
```bash
# Run all tests with default cipher suite (Curve25519 AES-128)
./run_kotlin_tests.sh

# Force refresh of bindings and libraries
./run_kotlin_tests.sh --force-refresh
```

### Cipher Suite Testing
```bash
# Test enterprise cipher suite (P-256 AES-128)
./run_kotlin_tests.sh 2

# Test mobile cipher suite (Curve25519 ChaCha)
./run_kotlin_tests.sh 3

# Test maximum security cipher suite (P-521 AES-256)
./run_kotlin_tests.sh 5
```

### Release Mode Testing
```bash
# Test with optimized release build
./run_kotlin_tests.sh --release

# Test specific cipher suite with release build
./run_kotlin_tests.sh --release 4  # Curve448 AES-256 (high security)
```

### Development Workflow
```bash
# Clean development cycle
./run_kotlin_tests.sh --force-refresh --release 7  # P-384 AES-256 (government)
```

## Build Modes

### Debug Mode (default)
- **Library Size**: ~8.4MB
- **Features**: Debug symbols, detailed error messages
- **Use Case**: Development and debugging

### Release Mode (`--release`)
- **Library Size**: ~2.5MB
- **Features**: Optimized performance, smaller size
- **Use Case**: Production testing and validation

## Test Runner Features

The `run_kotlin_tests.sh` script provides:

- **Automatic Bindings Generation**: Calls `../generate_kotlin_bindings.sh` as needed
- **Library Management**: Copies native libraries to test resources
- **Cipher Suite Selection**: Supports command-line cipher suite IDs
- **Build Mode Selection**: Debug vs release builds
- **Force Refresh**: Option to regenerate all bindings and libraries
- **Prerequisites Checking**: Validates required files and directories

## Manual Test Execution

If you prefer to run tests manually:

```bash
# Generate bindings first
cd ..
./generate_kotlin_bindings.sh  # or --release

# Copy bindings to test structure
cd tests
mkdir -p src/main/kotlin
cp -r ../bindings/uniffi src/main/kotlin/

# Copy native library
mkdir -p src/main/resources
cp ../bindings/*.dylib src/main/resources/

# Run tests
gradle test  # All tests
gradle test -Dmls.cipher.suite.id=5  # Specific cipher suite
```

## Troubleshooting

### Common Issues

1. **Library Not Found**
   - Ensure native library is in `src/main/resources/`
   - Check that `generate_kotlin_bindings.sh` completed successfully

2. **JNA Loading Issues**
   - Verify Java version is 22+
   - Check JVM arguments include `--enable-native-access=ALL-UNNAMED`

3. **Cipher Suite Errors**
   - Use valid cipher suite IDs (1-7)
   - Ensure bindings were generated with correct build mode

4. **Gradle Build Failures**
   - Clean build: `gradle clean`
   - Check Kotlin version compatibility

### Debug Commands

```bash
# Check library presence
ls -la src/main/resources/*.dylib

# Check bindings structure
find src/main/kotlin -name "*.kt"

# Verify Java version
java --version

# Check Gradle version
gradle --version
```

## Integration

To integrate these tests into your own project:

1. Copy the test structure to your project
2. Adjust `build.gradle.kts` dependencies as needed
3. Update package names in test files
4. Modify cipher suite selection logic if required
5. Add custom test cases for your specific use cases

## Performance Notes

- **BasicLoadTest**: Fastest validation, good for CI/CD
- **MLSAPITest**: Comprehensive but reasonable runtime
- **MLSComprehensiveTest**: Most thorough, suitable for release validation
- **Release vs Debug**: Release mode provides better performance testing
- **Cipher Suites**: Higher security cipher suites (P-521, Curve448) may be slower

## Contributing

When adding new tests:

1. Follow the existing naming conventions
2. Include proper error handling and assertions
3. Add comprehensive logging with emojis for clarity
4. Test with multiple cipher suites when applicable
5. Update this README with new test descriptions
