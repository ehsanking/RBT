plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // FCM push (BATCH 5): processes android/app/google-services.json. Version is
    // pinned in settings.gradle.kts (apply false); applied here.
    id("com.google.gms.google-services")
}

android {
    namespace = "com.woocommercemanager.wcp_premium"
    // file_picker's flutter_plugin_android_lifecycle needs compileSdk 36+.
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    ndkVersion = flutter.ndkVersion

    // AGP 8+ disables AIDL compilation by default. The Cafe Bazaar billing
    // service is bound via the bundled `com/farsitel/bazaar/*.aidl` stub, so
    // AIDL must be turned back on. This is a local toolchain feature — it does
    // NOT add any Maven dependency (Iran-safe; nothing fetched from
    // download.flutter.io).
    buildFeatures {
        aidl = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.woocommercemanager.wcp_premium"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // record 7.x / audioplayers require API 23+ (was flutter.minSdkVersion = 21).
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
    // FCM push (BATCH 5): Firebase Cloud Messaging via the Firebase Android SDK,
    // resolved from Google Maven (NOT pub.dev / NOT download.flutter.io) so it
    // stays Iran-safe. The BOM pins a consistent set of Firebase library
    // versions; firebase-messaging then needs no explicit version.
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-messaging")
}
