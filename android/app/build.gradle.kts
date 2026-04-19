import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties()
val keystoreFile = rootProject.file("key.properties")
if (keystoreFile.exists()) {
    FileInputStream(keystoreFile).use(keystoreProperties::load)
}

fun gradleOrEnv(name: String): String? {
    val envName = name.uppercase().replace('.', '_')
    return providers.gradleProperty(name).orNull
        ?: providers.environmentVariable(envName).orNull
}

fun String.escapeForBuildConfig(): String =
    replace("\\", "\\\\").replace("\"", "\\\"")

val configuredApplicationId =
    gradleOrEnv("detox.applicationId")?.trim().takeUnless { it.isNullOrEmpty() }
        ?: "com.example.detox"

val debugAdmobAppId = "ca-app-pub-3940256099942544~3347511713"
val debugRewardedAdUnitId = "ca-app-pub-3940256099942544/5224354917"
val releaseAdmobAppId =
    gradleOrEnv("detox.admob.appId.release")?.trim().takeUnless { it.isNullOrEmpty() }
val releaseRewardedAdUnitId =
    gradleOrEnv("detox.admob.rewardedId.release")?.trim().takeUnless { it.isNullOrEmpty() }

val hasReleaseSigning = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
).all { !keystoreProperties.getProperty(it).isNullOrBlank() }

android {
    namespace = "com.example.detox"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = configuredApplicationId
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // This app does not use Flutter deferred components. The manifest now
        // pins android:name to android.app.Application directly, so no
        // applicationName placeholder is needed here.
    }

    buildFeatures {
        buildConfig = true
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        debug {
            manifestPlaceholders["admobAppId"] = debugAdmobAppId
            buildConfigField("boolean", "ADS_ENABLED", "true")
            buildConfigField(
                "String",
                "REWARDED_AD_UNIT_ID",
                "\"${debugRewardedAdUnitId.escapeForBuildConfig()}\""
            )
        }

        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // Local release APKs must still be signed or Android will reject them
            // as invalid packages. Use the real release keystore when present;
            // otherwise fall back to the auto-generated debug keystore so the
            // resulting APK can be installed for local testing.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            manifestPlaceholders["admobAppId"] = releaseAdmobAppId ?: debugAdmobAppId
            buildConfigField(
                "boolean",
                "ADS_ENABLED",
                if (!releaseAdmobAppId.isNullOrBlank() && !releaseRewardedAdUnitId.isNullOrBlank()) "true" else "false"
            )
            buildConfigField(
                "String",
                "REWARDED_AD_UNIT_ID",
                "\"${(releaseRewardedAdUnitId ?: "").escapeForBuildConfig()}\""
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation(platform("com.google.firebase:firebase-bom:33.12.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.android.gms:play-services-ads:23.6.0")
}
