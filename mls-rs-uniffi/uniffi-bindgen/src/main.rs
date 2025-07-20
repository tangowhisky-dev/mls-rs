use std::env;

fn main() {
    // Check for iOS-specific command line arguments
    let args: Vec<String> = env::args().collect();
    
    // Look for iOS-specific flags and set environment variables
    for i in 0..args.len() {
        match args[i].as_str() {
            "--swift-out-dir" => {
                if i + 1 < args.len() {
                    env::set_var("UNIFFI_SWIFT_OUT_DIR", &args[i + 1]);
                }
            }
            "--framework-name" => {
                if i + 1 < args.len() {
                    env::set_var("UNIFFI_FRAMEWORK_NAME", &args[i + 1]);
                }
            }
            "--ios-deployment-target" => {
                if i + 1 < args.len() {
                    env::set_var("UNIFFI_IOS_DEPLOYMENT_TARGET", &args[i + 1]);
                }
            }
            _ => {}
        }
    }
    
    // Call the standard uniffi bindgen main function
    uniffi::uniffi_bindgen_main()
}
