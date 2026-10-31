pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

// Kept in the project so reproduce.sh starts from an empty cache.
buildCache {
    local {
        directory = file(".gradle/build-cache")
    }
}

rootProject.name = "sentry-gradle-config-cache-repro"

include(":app")
