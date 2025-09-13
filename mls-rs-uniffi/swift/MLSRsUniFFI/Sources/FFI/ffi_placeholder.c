// Minimal source to force Xcode/SwiftPM to build the FFI target and link headers-only module.
// This avoids "FFI.o not found" when the target previously contained only headers.
int mlsrs_uniffi_ffi_placeholder(void) { return 0; }
