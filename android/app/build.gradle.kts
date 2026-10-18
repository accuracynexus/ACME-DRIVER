plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// La clave de Google Maps se lee del .env del proyecto y se inyecta en el
// AndroidManifest al compilar. Asi no queda escrita en ningun archivo que se
// suba al repositorio (.env esta en .gitignore).
import java.util.Properties

var mapsApiKey = "tu_google_maps_api_key_aqui"
val envFile = rootProject.file("../.env")
if (envFile.exists()) {
    val envProps = Properties()
    envFile.inputStream().use { envProps.load(it) }
    mapsApiKey = envProps.getProperty("GOOGLE_MAPS_API_KEY") ?: mapsApiKey
}

android {
    namespace = "com.acme.acme_driver"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.acme.acme_driver"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}