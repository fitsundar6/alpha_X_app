import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeyProperties = keystorePropertiesFile.exists()
if (hasKeyProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.alphax.gym.alpha_x_gym"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.alphax.gym.alpha_x_gym"
        // Health Connect requires minSdk 26+
        minSdk = 26
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasKeyProperties && keystorePropertiesFile.isFile) {
                val storeFilePath = keystoreProperties.getProperty("storeFile")
                val keyAliasVal = keystoreProperties.getProperty("keyAlias")
                val storePassVal = keystoreProperties.getProperty("storePassword")
                val keyPassVal = keystoreProperties.getProperty("keyPassword")

                if (storeFilePath.isNullOrBlank() || keyAliasVal.isNullOrBlank() ||
                    storePassVal.isNullOrBlank() || keyPassVal.isNullOrBlank()) {
                    throw GradleException(
                        "Release signing configuration error: 'apps/mobile/android/key.properties' is missing required fields " +
                        "(storeFile, storePassword, keyAlias, keyPassword)."
                    )
                }

                val resolvedStoreFile = rootProject.file(storeFilePath)
                if (resolvedStoreFile.exists()) {
                    storeFile = resolvedStoreFile
                } else {
                    val appStoreFile = file(storeFilePath)
                    if (appStoreFile.exists()) {
                        storeFile = appStoreFile
                    } else {
                        throw GradleException(
                            "Release signing configuration error: Keystore file '$storeFilePath' specified in key.properties does not exist."
                        )
                    }
                }

                keyAlias = keyAliasVal
                keyPassword = keyPassVal
                storePassword = storePassVal
            }
        }
    }

    buildTypes {
        release {
            // Strictly enforce release signing configuration. Never fall back silently to debug signing.
            signingConfig = signingConfigs.getByName("release")
            // Disable minification and resource shrinking to avoid R8/ProGuard issues in CI
            isMinifyEnabled = false
            isShrinkResources = false
            ndk {
                // Suppress NDK debug symbol stripping — avoids CI native-lib strip failures
                debugSymbolLevel = "none"
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val releaseTasks = allTasks.filter {
        it.name.contains("Release", ignoreCase = true) && !it.name.contains("lint", ignoreCase = true)
    }
    if (releaseTasks.isNotEmpty() && (!hasKeyProperties || !keystorePropertiesFile.isFile)) {
        throw GradleException(
            "\n========================================================================\n" +
            "❌ PRODUCTION RELEASE SIGNING ERROR:\n" +
            "Release build aborted: 'apps/mobile/android/key.properties' was not found.\n\n" +
            "Alpha X Gym enforces strict production signing and DOES NOT permit\n" +
            "silent fallback to debug signing for release artifacts.\n\n" +
            "To build a production signed release:\n" +
            "  1. Ensure your authorized production keystore exists (e.g. apps/mobile/android/app/upload-keystore.jks)\n" +
            "  2. Create untracked 'apps/mobile/android/key.properties' (see key.properties.example)\n" +
            "  3. Configure: storeFile, storePassword, keyAlias, keyPassword\n" +
            "========================================================================\n"
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
