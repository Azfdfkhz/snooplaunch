import java.util.Properties

// Update 1.5.1: tanda tangan tetap supaya APK baru bisa dipasang SEBAGAI UPDATE (data aplikasi tidak hilang).
// Tanpa ini setiap mesin build memakai debug key yang berbeda, Android menolak update, dan pengguna terpaksa
// uninstall: seluruh data lokal (profil, memories) ikut terhapus. Lihat UPDATE_1_5_1_REPORT.md.
val keystoreProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.snoop"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Core library desugaring diperlukan oleh flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.snoop"
        // flutter_local_notifications dan geolocator butuh minimal API 21
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("snoop") {
            val file = keystoreProps.getProperty("storeFile")
            if (file != null) {
                storeFile = rootProject.file(file)
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        // Bila android/key.properties ada, debug dan release memakai kunci yang sama; bila tidak, perilaku lama (debug key).
        val signing = if (keystoreProps.getProperty("storeFile") != null) signingConfigs.getByName("snoop") else signingConfigs.getByName("debug")
        debug {
            signingConfig = signing
        }
        release {
            signingConfig = signing
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

dependencies {
    // Core library desugaring — dibutuhkan oleh flutter_local_notifications untuk Java 8+ APIs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
