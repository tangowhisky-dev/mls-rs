// Simple build script that doesn't generate Swift bindings during compilation
// Swift bindings should be generated separately using the build-xcframework.sh script

fn main() {
    println!("cargo:warning=MLS-RS UniFFI build script running");
    
    // Just emit the rerun directives
    println!("cargo:rerun-if-changed=src/");
    println!("cargo:rerun-if-changed=Cargo.toml");
    
    println!("cargo:warning=Build script completed - use ./bindings/build-xcframework.sh to generate Swift bindings");
}
