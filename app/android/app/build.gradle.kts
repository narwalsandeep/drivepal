plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

fun loadGoogleMapsEnvValue(repoRoot: java.io.File): String {
    val env = java.io.File(repoRoot, ".env")
    if (!env.exists()) return ""
    env.readLines(java.nio.charset.StandardCharsets.UTF_8).forEach { raw ->
        val line = raw.trim()
        if (line.isEmpty() || line.startsWith("#")) return@forEach
        val i = line.indexOf('=')
        if (i <= 0) return@forEach
        val k = line.substring(0, i).trim()
        if (k != "GOOGLE_MAPS_API_KEY") return@forEach
        var v = line.substring(i + 1).trim()
        if (v.length >= 2) {
            if ((v.startsWith("\"") && v.endsWith("\"")) ||
                (v.startsWith("'") && v.endsWith("'"))
            ) {
                v = v.substring(1, v.length - 1)
            }
        }
        return v
    }
    return ""
}

android {
    namespace = "com.drivepal.drivepal_app"
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
        applicationId = "com.drivepal.drivepal_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        val repoRoot = rootProject.projectDir.parentFile.parentFile
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] =
            loadGoogleMapsEnvValue(repoRoot)
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
