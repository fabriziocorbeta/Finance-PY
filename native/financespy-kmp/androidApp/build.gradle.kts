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
        applicationId = "py.com.cdco.financespy.dev"
        minSdk = 26
        targetSdk = 36
        versionCode = 4
        versionName = "0.1.0-layout-fix"
    }

    buildTypes {
        release { isMinifyEnabled = false }
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
    implementation(project(":shared"))
    implementation(compose.runtime)
    implementation(libs.androidx.activity.compose)
    implementation(libs.ktor.client.core)
    implementation(libs.room.runtime)
    implementation(libs.kotlinx.coroutines.core)
}
