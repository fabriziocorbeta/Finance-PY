-dontwarn com.google.errorprone.annotations.**

# Ktor
-keep class io.ktor.** { *; }

# Kotlinx Serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKd
-keep,allowobfuscation,allowshrinking class kotlinx.serialization.internal.**
-keep,allowobfuscation,allowshrinking class * implements kotlinx.serialization.KSerializer {
    <init>();
}
-keepclassmembers class * {
    @kotlinx.serialization.Serializable *;
}

# Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# General Keep for models and specific things the app might use heavily via reflection
-keep class py.com.cdco.financespy.network.dto.** { *; }
-keep class py.com.cdco.financespy.db.entity.** { *; }

# Suppress missing java.lang.management classes from Ktor/Kotlinx
-dontwarn java.lang.management.**

# Strip debug/verbose/info Log calls from release builds -- these can carry
# sensitive data (tokens, request bodies) and must not ship in the APK.
# Keeps warn/error, which is what production crash triage relies on.
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
    public static int i(...);
}
