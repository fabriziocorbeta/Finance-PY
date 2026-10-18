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
        // Same pattern as the release keystore below: comes from an env var
        // (CI secret or a local shell export), never committed. An empty
        // value is a valid state -- Maps Compose just renders a blank/grey
        // tile instead of crashing, same as any build without the key set.
        manifestPlaceholders["googleMapsApiKey"] = System.getenv("GOOGLE_MAPS_API_KEY") ?: ""
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
    // Best-effort device location at Wallet capture time (see
    // WalletCaptureHandler) -- only used here, androidApp-only.
    implementation(libs.play.services.location)
    // EncryptedSharedPreferences for AndroidOfflineStore / AndroidDashboardCache /
    // PendingCaptureStore / OwnerScope. `shared` also depends on this but only as
    // `implementation`, which isn't exposed transitively -- declared again here for
    // the same reason. Keep in sync with shared/build.gradle.kts.
    implementation("androidx.security:security-crypto:1.1.0-alpha06")
}

dependencies {
    testImplementation("junit:junit:4.13.2")
    // android.jar's org.json classes are stubs that throw at runtime
    // ("not mocked") under a plain JVM unit test -- this is a real
    // implementation on the test classpath so PendingCaptureStoreTest can
    // actually exercise JSONObject/JSONArray without Robolectric.
    testImplementation("org.json:json:20231013")
}
