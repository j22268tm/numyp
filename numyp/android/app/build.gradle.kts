plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.numyp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.numyp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // env.json から API キーを読み込む
        val envFile = file("../../env.json")
        var gmapKey = ""
        if (envFile.exists()) {
            try {
                val jsonContent = envFile.readText()
                val gmapKeyMatch = """"GMAP_API_KEY"\s*:\s*"([^"]+)"""".toRegex().find(jsonContent)
                gmapKey = gmapKeyMatch?.groupValues?.get(1) ?: ""
            } catch (e: Exception) {
                logger.warn("Failed to read GMAP_API_KEY from env.json: ${e.message}")
            }
        }
        resValue("string", "GMAP_KEY", gmapKey)
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
