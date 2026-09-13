plugins {
    id("com.android.application")
}

android {
    namespace = "com.mlsrs.testbed"
    compileSdk = 35

    defaultConfig {
        applicationId = "com.mlsrs.testbed"
        minSdk = 24
        targetSdk = 35
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    sourceSets {
        // Kotlin UniFFI bindings live alongside the app sources.
        getByName("main") {
            java.srcDir("src/main/java")
            jniLibs.srcDir("src/main/jniLibs")
        }
    }
}

dependencies {
    implementation("net.java.dev.jna:jna:5.18.1@aar")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.10.2")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test:rules:1.7.0")
}
