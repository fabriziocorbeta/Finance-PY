pluginManagement {
    repositories {
        maven("https://repo.huaweicloud.com/repository/maven/")
        google()
        maven("https://maven.google.com")
        maven("https://dl.google.com/dl/android/maven2/")
        gradlePluginPortal()
        mavenCentral()
        maven("https://maven.pkg.jetbrains.space/public/p/compose/dev")
    }
}
dependencyResolutionManagement {
    repositories {
        maven("https://repo.huaweicloud.com/repository/maven/")
        google()
        mavenCentral()
        maven("https://maven.pkg.jetbrains.space/public/p/compose/dev")
    }
}
rootProject.name = "financespy-kmp"
include(":shared", ":androidApp")
