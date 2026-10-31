plugins {
    id("com.android.application")
    id("io.sentry.android.gradle")
}

android {
    namespace = "com.example.repro"
    compileSdk = 37

    defaultConfig {
        applicationId = "com.example.repro"
        minSdk = 24
    }
}

sentry {
    autoUploadProguardMapping = false
    includeProguardMapping = false
    telemetry = false
    autoInstallation.enabled = false
}

dependencies {
    implementation("io.sentry:sentry-android-core:8.62.0")
}
