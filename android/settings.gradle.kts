pluginManagement {
    val flutterSdkPath = run {
        val localPropsFile = file("local.properties")
        if (localPropsFile.exists()) {
            val properties = java.util.Properties()
            localPropsFile.inputStream().use { properties.load(it) }
            properties.getProperty("flutter.sdk")
        } else {
            // Fallback: let flutter pub get create local.properties, or use env var
            System.getenv("FLUTTER_SDK")?.also { path ->
                localPropsFile.writeText("flutter.sdk=$path\n")
            }
        }
            ?: throw GradleException(
                "flutter.sdk not set in local.properties.\n" +
                "Run 'flutter pub get' in the project root first, or manually set flutter.sdk in android/local.properties."
            )
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.0.21" apply false
}

include(":app")