import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeyProperties = keystorePropertiesFile.exists() && keystorePropertiesFile.isFile
if (hasKeyProperties) {
    try {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    } catch (_: Exception) {}
}

val storeFilePath = if (hasKeyProperties) keystoreProperties.getProperty("storeFile") else null
val keyAliasVal = if (hasKeyProperties) keystoreProperties.getProperty("keyAlias") else null
val storePassVal = if (hasKeyProperties) keystoreProperties.getProperty("storePassword") else null
val keyPassVal = if (hasKeyProperties) keystoreProperties.getProperty("keyPassword") else null

val resolvedStoreFile = if (!storeFilePath.isNullOrBlank()) {
    val rootFile = rootProject.file(storeFilePath)
    if (rootFile.exists()) rootFile else file(storeFilePath)
} else null

val hasValidSigningConfig = hasKeyProperties &&
    resolvedStoreFile != null && resolvedStoreFile.exists() &&
    !keyAliasVal.isNullOrBlank() &&
    !storePassVal.isNullOrBlank() &&
    !keyPassVal.isNullOrBlank() &&
    !storePassVal.contains("your_") &&
    !keyPassVal.contains("your_")

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
            if (hasValidSigningConfig) {
                storeFile = resolvedStoreFile
                keyAlias = keyAliasVal
                keyPassword = keyPassVal
                storePassword = storePassVal
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasValidSigningConfig) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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
    if (releaseTasks.isNotEmpty()) {
        if (hasValidSigningConfig) {
            println("✔ [SIGNING] Using production keystore configuration from 'apps/mobile/android/key.properties'.")
        } else {
            println(
                "\n========================================================================\n" +
                "ℹ️ NOTICE: 'key.properties' not configured with valid production credentials.\n" +
                "Signing release artifact with debug keys (suitable for direct sideloading and CI testing).\n" +
                "To sign with your official production keystore for Google Play:\n" +
                "  1. Ensure your keystore exists (e.g. apps/mobile/android/app/upload-keystore.jks)\n" +
                "  2. Configure 'apps/mobile/android/key.properties' (see key.properties.example)\n" +
                "========================================================================\n"
            )
        }
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
