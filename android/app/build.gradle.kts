import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}


// Carga la clave de Maps desde el .env de la raíz del repo (no versionado)
// para inyectarla en el manifest sin comitear la clave real, igual que el
// resto de secretos del proyecto (ver AppSecrets en el lado Dart).
val dotEnvFile = rootProject.file("../.env")
val dotEnvLines: List<String> = dotEnvFile.takeIf { it.exists() }?.readLines().orEmpty()

fun dotEnv(name: String): String? = dotEnvLines
    .firstOrNull { it.trim().startsWith("$name=") }
    ?.substringAfter("=")
    ?.trim()
    ?.takeIf { it.isNotEmpty() }

// El .env lo comparten dos consumidores que necesitan claves distintas: el
// build de web lo lee con --dart-define-from-file y usa la clave *Browser*,
// mientras que el manifest de Android necesita la clave *Android*. Por eso se
// mira primero el nombre sufijado; GOOGLE_MAPS_API_KEY a secas queda como
// fallback para los .env antiguos que solo tenian una clave.
// En CI no hay .env (esta en .gitignore), asi que se cae a la variable de
// entorno que el workflow rellena desde el secreto del repo. Sin esto el APK
// que construye Actions sale con el placeholder vacio y los mapas no cargan.
val googleMapsApiKey: String = dotEnv("GOOGLE_MAPS_API_KEY_ANDROID")
    ?: dotEnv("GOOGLE_MAPS_API_KEY")
    ?: System.getenv("GOOGLE_MAPS_API_KEY")
    ?: ""

// Firma de release. android/key.properties esta en .gitignore; si no existe
// (clon limpio, CI sin secretos) se cae a la clave de debug para no romper
// `flutter run --release`, pero avisando: un APK firmado con la debug keystore
// del runner tiene un SHA-1 distinto al registrado en Firebase y Google
// Sign-In falla con ApiException 10.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasReleaseSigning = keystorePropertiesFile.exists()

android {
    namespace = "com.autodoc.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.autodoc.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] = googleMapsApiKey
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "AVISO: no hay android/key.properties; el APK de release se " +
                    "firmara con la clave de debug. Instalable, pero Google " +
                    "Sign-In solo funcionara si ese SHA-1 esta registrado en Firebase."
                )
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
