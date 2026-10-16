// Clean up conflicting Android environment variables (ANDROID_PREFS_ROOT vs ANDROID_USER_HOME)
run {
    try {
        val env = System.getenv()
        val field = env.javaClass.getDeclaredField("m")
        field.isAccessible = true
        @Suppress("UNCHECKED_CAST")
        val map = field.get(env) as MutableMap<String, String>
        map.remove("ANDROID_PREFS_ROOT")
        map.remove("ANDROID_SDK_HOME")
    } catch (_: Exception) {
        try {
            val pe = Class.forName("java.lang.ProcessEnvironment")
            val peField = pe.getDeclaredField("theCaseInsensitiveEnvironment")
            peField.isAccessible = true
            @Suppress("UNCHECKED_CAST")
            val peMap = peField.get(null) as MutableMap<String, String>
            peMap.remove("ANDROID_PREFS_ROOT")
            peMap.remove("ANDROID_SDK_HOME")
        } catch (_: Exception) {}
    }
}

pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
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
    id("com.android.application") version "9.4.0" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    id("com.google.gms.google-services") version "4.5.0" apply false
    id("org.gradle.toolchains.foojay-resolver-convention") version "1.0.0"
}

include(":app")
