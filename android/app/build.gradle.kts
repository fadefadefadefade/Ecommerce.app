import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The release signing key (android/key.properties and the .jks are never committed). The same key must sign every
// release, or Android refuses to update the installed app.
val keyProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "com.example.alvy_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.alvy_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = rootProject.file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // The release key when android/key.properties exists; otherwise the debug key (other computers can still build and test).
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // FileProvider, for the in-app update.
    implementation("androidx.core:core-ktx:1.13.1")
}

// Every release build is also saved as "ALVY Shop.apk", next to Flutter's app-release.apk
// (build/app/outputs/flutter-apk/), ready to share or upload.
val copyAlvyShopApk = tasks.register("copyAlvyShopApk") {
    doLast {
        val dir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
        val apk = File(dir, "app-release.apk")
        if (apk.exists()) {
            apk.copyTo(File(dir, "ALVY Shop.apk"), overwrite = true)
        }
    }
}
tasks.matching { it.name == "assembleRelease" }.configureEach { finalizedBy(copyAlvyShopApk) }
