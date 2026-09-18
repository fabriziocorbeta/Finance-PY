plugins {
    alias(libs.plugins.androidApplication)
    id("org.jetbrains.kotlin.android")
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
}

android {
    namespace = "py.com.cdco.financespy"
    compileSdk = 36

    defaultConfig {
        applicationId = "py.com.cdco.financespy"
        minSdk = 26
        targetSdk = 36
        versionCode = 4
        versionName = "0.1.0-layout-fix"
    }

    // Release keystore comes from env vars (CI secrets) -- never committed,
    // never present for a local build. A release build with no keystore
    // configured simply isn't signed; there's no local JDK 17 to build it
    // with anyway, this only ever runs in CI.
    val releaseKeystorePath = System.getenv("FINANCESPY_RELEASE_KEYSTORE_PATH")
    signingConfigs {
        if (releaseKeystorePath != null) {
            create("release") {
                storeFile = file(releaseKeystorePath)
                storePassword = System.getenv("FINANCESPY_RELEASE_STORE_PASSWORD")
                keyAlias = System.getenv("FINANCESPY_RELEASE_KEY_ALIAS")
                keyPassword = System.getenv("FINANCESPY_RELEASE_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        debug {
            // Same package id the app has always shipped under for testing --
            // installs side by side with a signed release build, which uses
            // the clean applicationId above.
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "FinancePY (dev)"
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            manifestPlaceholders["appLabel"] = "FinancePY"
            if (releaseKeystorePath != null) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }
}

dependencies {
    implementation(compose.material)
    implementation(compose.material3)
    implementation(compose.foundation)
    implementation(libs.androidx.biometric)
    implementation(libs.androidx.appcompat)
    implementation(project(":shared"))
    implementation(compose.runtime)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.core.splashscreen)
    implementation(libs.ktor.client.core)
    implementation(libs.room.runtime)
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.lifecycle.process)
}
