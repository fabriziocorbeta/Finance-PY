plugins {
    alias(libs.plugins.androidApplication)
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
        versionCode = 1
        versionName = "0.1.0-1a"
    }

    buildTypes {
        release { isMinifyEnabled = false }
    }
}

dependencies {
    implementation(project(":shared"))
}
