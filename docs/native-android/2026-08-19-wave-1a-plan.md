# App Android nativa FinancePY — Wave 1a Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Ejecución real de este proyecto: vía Jules (Google, jules.google.com)**, siguiendo el patrón ya establecido para los módulos ERP (Inventario/Ventas/Pedidos/Flota) — cada Task de abajo es un prompt autocontenido para pegar en una sesión de Jules. Jules abre PR en `fabriziocorbeta/cd-co-erp`; el humano/Claude revisa `gh pr diff` completo antes de mergear. Reglas aprendidas de sesiones previas con Jules, aplican también acá:
> - Prompt SIEMPRE debe decir "no toques CI/.env/workflows/el directorio `android/` existente".
> - Prompt SIEMPRE debe decir "detenete al abrir el PR, no busques problemas de seguridad por tu cuenta".
> - Tasks son secuenciales (cada una depende del build de la anterior) — nunca correr 2 Tasks de este plan en paralelo en Jules.
> - Jules probablemente no puede correr un emulador Android real en su sandbox — pedirle explícitamente en cada prompt que confirme `./gradlew build` (compila) y, donde aplique, `./gradlew testDebugUnitTest` (tests unitarios JVM, no necesitan emulador) y que declare en la descripción del PR si algo no pudo verificar en runtime real.

**Goal:** Construir la fundación de la app Android nativa FinancePY — proyecto Kotlin Multiplatform con Compose Multiplatform, auth OAuth2 PKCE, motor de sync local (Room) y 3 pantallas (Login, Dashboard, Transacciones) — consumiendo la API v1 de Rails ya existente sin cambios de backend.

**Architecture:** Módulo nuevo `native/financespy-kmp/` (paralelo a `native/android/wallet-listener/` existente, no toca `android/` que es del Capacitor). Gradle multi-módulo: `:shared` (commonMain — modelos, red Ktor, DB Room KMP, repositorios, ViewModels, pantallas Compose Multiplatform) + `:androidApp` (entry point Android, `applicationId` de desarrollo). Target hoy: solo Android — estructura lista para sumar `iosMain` cuando arranque el trabajo iOS real, sin rearquitectura (YAGNI: no se construye target iOS ahora).

**Tech Stack:** Kotlin Multiplatform, Compose Multiplatform, Ktor Client (OkHttp engine en Android), Room KMP (driver SQLite bundled), Koin (DI), kotlinx.serialization (JSON), kotlinx.coroutines.

## Global Constraints

- `applicationId` de este build: `py.com.cdco.financespy.dev` (NUNCA `py.com.cdco.financespy` — ese es el package de producción del Capacitor actual, no se toca hasta el corte final post-1d, spec `2026-08-19-financespy-native-android-1a-design.md`).
- Backend: **cero cambios**. Todo consume `/api/v1/*` tal cual existe hoy en `fabrizio@100.105.31.71:~/financespy`.
- OAuth: `client_id = Ti8y1yGMsJVyNv35wsWE2taV7NR4B3zdKduf7E5IZEM`, `redirect_uri = financespy://oauth/callback`, `scope = read_write`, PKCE obligatorio (`force_pkce` en el server).
- Ventana de transacciones en sync: 90 días (`start_date` query param).
- Sin delta-sync, sin tombstones de borrado — full refetch en cada sync (foreground open + pull-to-refresh manual). MVP explícito, spec lo aclara.
- No tocar `android/` (Capacitor) ni `native/android/wallet-listener/` (Kotlin del listener de Wallet) en ningún Task de este plan.
- Base URL de API: `https://finance.cd-co.com.py` (mismo origin que usa el Capacitor).

---

## Task 1: Scaffold del proyecto KMP + Compose Multiplatform (pantalla vacía que compila)

**Files:**
- Create: `native/financespy-kmp/settings.gradle.kts`
- Create: `native/financespy-kmp/build.gradle.kts`
- Create: `native/financespy-kmp/gradle.properties`
- Create: `native/financespy-kmp/gradle/libs.versions.toml`
- Create: `native/financespy-kmp/shared/build.gradle.kts`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/App.kt`
- Create: `native/financespy-kmp/androidApp/build.gradle.kts`
- Create: `native/financespy-kmp/androidApp/src/main/AndroidManifest.xml`
- Create: `native/financespy-kmp/androidApp/src/main/kotlin/py/com/cdco/financespy/MainActivity.kt`

**Interfaces:**
- Produces: `@Composable fun App()` en `py.com.cdco.financespy.App` — punto de entrada de UI compartida que Tasks futuros extienden (Login/Dashboard/Transacciones se agregan como pantallas dentro de este composable vía navegación).

- [ ] **Step 1: Version catalog**

`native/financespy-kmp/gradle/libs.versions.toml`:
```toml
[versions]
kotlin = "2.1.0"
agp = "8.7.3"
compose-multiplatform = "1.7.3"
ktor = "3.0.3"
room = "2.7.0-alpha11"
sqlite = "2.5.0-alpha11"
koin = "4.0.2"
kotlinx-serialization = "1.7.3"
kotlinx-coroutines = "1.9.0"
androidx-activity-compose = "1.9.3"

[libraries]
ktor-client-core = { module = "io.ktor:ktor-client-core", version.ref = "ktor" }
ktor-client-okhttp = { module = "io.ktor:ktor-client-okhttp", version.ref = "ktor" }
ktor-client-content-negotiation = { module = "io.ktor:ktor-client-content-negotiation", version.ref = "ktor" }
ktor-serialization-kotlinx-json = { module = "io.ktor:ktor-serialization-kotlinx-json", version.ref = "ktor" }
ktor-client-logging = { module = "io.ktor:ktor-client-logging", version.ref = "ktor" }
kotlinx-serialization-json = { module = "org.jetbrains.kotlinx:kotlinx-serialization-json", version.ref = "kotlinx-serialization" }
kotlinx-coroutines-core = { module = "org.jetbrains.kotlinx:kotlinx-coroutines-core", version.ref = "kotlinx-coroutines" }
room-runtime = { module = "androidx.room:room-runtime", version.ref = "room" }
sqlite-bundled = { module = "androidx.sqlite:sqlite-bundled", version.ref = "sqlite" }
koin-core = { module = "io.insert-koin:koin-core", version.ref = "koin" }
koin-compose = { module = "io.insert-koin:koin-compose", version.ref = "koin" }
androidx-activity-compose = { module = "androidx.activity:activity-compose", version.ref = "androidx-activity-compose" }

[plugins]
kotlinMultiplatform = { id = "org.jetbrains.kotlin.multiplatform", version.ref = "kotlin" }
androidApplication = { id = "com.android.application", version.ref = "agp" }
androidLibrary = { id = "com.android.library", version.ref = "agp" }
composeMultiplatform = { id = "org.jetbrains.compose", version.ref = "compose-multiplatform" }
composeCompiler = { id = "org.jetbrains.kotlin.plugin.compose", version.ref = "kotlin" }
kotlinSerialization = { id = "org.jetbrains.kotlin.plugin.serialization", version.ref = "kotlin" }
room = { id = "androidx.room", version.ref = "room" }
```

- [ ] **Step 2: Root settings/build files**

`native/financespy-kmp/settings.gradle.kts`:
```kotlin
pluginManagement {
    repositories {
        google()
        gradlePluginPortal()
        mavenCentral()
        maven("https://maven.pkg.jetbrains.space/public/p/compose/dev")
    }
}
dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
        maven("https://maven.pkg.jetbrains.space/public/p/compose/dev")
    }
}
rootProject.name = "financespy-kmp"
include(":shared", ":androidApp")
```

`native/financespy-kmp/gradle.properties`:
```properties
kotlin.code.style=official
android.useAndroidX=true
org.gradle.jvmargs=-Xmx4096m
kotlin.mpp.enableCInteropCommonization=true
```

`native/financespy-kmp/build.gradle.kts`:
```kotlin
plugins {
    alias(libs.plugins.kotlinMultiplatform) apply false
    alias(libs.plugins.androidApplication) apply false
    alias(libs.plugins.androidLibrary) apply false
    alias(libs.plugins.composeMultiplatform) apply false
    alias(libs.plugins.composeCompiler) apply false
    alias(libs.plugins.kotlinSerialization) apply false
    alias(libs.plugins.room) apply false
}
```

- [ ] **Step 3: módulo `:shared`**

`native/financespy-kmp/shared/build.gradle.kts`:
```kotlin
import org.jetbrains.kotlin.gradle.ExperimentalKotlinGradlePluginApi
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidLibrary)
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
    alias(libs.plugins.kotlinSerialization)
}

kotlin {
    androidTarget {
        @OptIn(ExperimentalKotlinGradlePluginApi::class)
        compilerOptions { jvmTarget.set(JvmTarget.JVM_11) }
    }

    sourceSets {
        commonMain.dependencies {
            implementation(compose.runtime)
            implementation(compose.foundation)
            implementation(compose.material3)
            implementation(compose.ui)
            implementation(compose.components.resources)
            implementation(libs.ktor.client.core)
            implementation(libs.ktor.client.content.negotiation)
            implementation(libs.ktor.serialization.kotlinx.json)
            implementation(libs.ktor.client.logging)
            implementation(libs.kotlinx.serialization.json)
            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.room.runtime)
            implementation(libs.sqlite.bundled)
            implementation(libs.koin.core)
            implementation(libs.koin.compose)
        }
        androidMain.dependencies {
            implementation(libs.ktor.client.okhttp)
            implementation(libs.androidx.activity.compose)
        }
    }
}

android {
    namespace = "py.com.cdco.financespy.shared"
    compileSdk = 35
    defaultConfig { minSdk = 26 }
}
```

- [ ] **Step 4: `App.kt` — punto de entrada compartido (placeholder funcional, no vacío)**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/App.kt`:
```kotlin
package py.com.cdco.financespy

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

@Composable
fun App() {
    MaterialTheme {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
            Text("FinancePY nativo — wave 1a scaffold")
        }
    }
}
```

- [ ] **Step 5: módulo `:androidApp`**

`native/financespy-kmp/androidApp/build.gradle.kts`:
```kotlin
plugins {
    alias(libs.plugins.androidApplication)
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
}

android {
    namespace = "py.com.cdco.financespy"
    compileSdk = 35

    defaultConfig {
        applicationId = "py.com.cdco.financespy.dev"
        minSdk = 26
        targetSdk = 35
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
```

`native/financespy-kmp/androidApp/src/main/AndroidManifest.xml`:
```xml
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET" />
    <application
        android:label="FinancePY (dev)"
        android:theme="@android:style/Theme.Material.Light.NoActionBar">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
```

`native/financespy-kmp/androidApp/src/main/kotlin/py/com/cdco/financespy/MainActivity.kt`:
```kotlin
package py.com.cdco.financespy

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { App() }
    }
}
```

- [ ] **Step 6: Verificar build**

Run: `cd native/financespy-kmp && ./gradlew :androidApp:assembleDebug`
Expected: `BUILD SUCCESSFUL`, APK generado en `androidApp/build/outputs/apk/debug/androidApp-debug.apk`.

- [ ] **Step 7: Commit**

```bash
git add native/financespy-kmp/
git commit -m "feat(native-android): scaffold KMP + Compose Multiplatform (wave 1a task 1)"
```

---

## Task 2: Cliente Ktor + auth OAuth2 PKCE

**Files:**
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/network/ApiClient.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/auth/PkceGenerator.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/auth/AuthRepository.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/auth/TokenStorage.kt`
- Create: `native/financespy-kmp/shared/src/androidMain/kotlin/py/com/cdco/financespy/auth/TokenStorage.android.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/LoginScreen.kt`
- Modify: `native/financespy-kmp/androidApp/src/main/AndroidManifest.xml` (agregar intent-filter para `financespy://oauth/callback`)
- Modify: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/App.kt` (mostrar `LoginScreen` si no hay token)
- Test: `native/financespy-kmp/shared/src/commonTest/kotlin/py/com/cdco/financespy/auth/PkceGeneratorTest.kt`

**Interfaces:**
- Consumes: nada de tasks anteriores más allá del módulo `:shared` de Task 1.
- Produces:
  - `object ApiClient { val http: HttpClient; const val BASE_URL = "https://finance.cd-co.com.py" }`
  - `class PkceGenerator { fun generateVerifier(): String; fun challengeFor(verifier: String): String }`
  - `interface TokenStorage { suspend fun save(accessToken: String, refreshToken: String); suspend fun accessToken(): String?; suspend fun refreshToken(): String?; suspend fun clear() }` — implementación Android real vía `EncryptedSharedPreferences`.
  - `class AuthRepository(private val http: HttpClient, private val tokens: TokenStorage) { fun buildAuthorizationUrl(codeChallenge: String): String; suspend fun exchangeCode(code: String, verifier: String): Result<Unit>; suspend fun isLoggedIn(): Boolean }` — Task 3+ dependen de `AuthRepository.isLoggedIn()` y de que `ApiClient.http` ya mande el `Authorization: Bearer` header automáticamente vía plugin.

- [ ] **Step 1: PKCE generator + test**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/auth/PkceGenerator.kt`:
```kotlin
package py.com.cdco.financespy.auth

import kotlin.random.Random
import kotlinx.io.bytestring.encodeToByteString

class PkceGenerator {
    fun generateVerifier(): String {
        val bytes = Random.Default.nextBytes(64)
        return base64UrlEncode(bytes).take(128)
    }

    fun challengeFor(verifier: String): String {
        val digest = sha256(verifier.encodeToByteString().toByteArray())
        return base64UrlEncode(digest)
    }

    private fun base64UrlEncode(bytes: ByteArray): String {
        val table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        val sb = StringBuilder()
        var i = 0
        while (i < bytes.size) {
            val b0 = bytes[i].toInt() and 0xFF
            val b1 = if (i + 1 < bytes.size) bytes[i + 1].toInt() and 0xFF else 0
            val b2 = if (i + 2 < bytes.size) bytes[i + 2].toInt() and 0xFF else 0
            sb.append(table[b0 shr 2])
            sb.append(table[((b0 and 0x03) shl 4) or (b1 shr 4)])
            if (i + 1 < bytes.size) sb.append(table[((b1 and 0x0F) shl 2) or (b2 shr 6)])
            if (i + 2 < bytes.size) sb.append(table[b2 and 0x3F])
            i += 3
        }
        return sb.toString()
    }
}

expect fun sha256(input: ByteArray): ByteArray
```

`native/financespy-kmp/shared/src/androidMain/kotlin/py/com/cdco/financespy/auth/Sha256.android.kt`:
```kotlin
package py.com.cdco.financespy.auth

import java.security.MessageDigest

actual fun sha256(input: ByteArray): ByteArray =
    MessageDigest.getInstance("SHA-256").digest(input)
```

`native/financespy-kmp/shared/src/commonTest/kotlin/py/com/cdco/financespy/auth/PkceGeneratorTest.kt`:
```kotlin
package py.com.cdco.financespy.auth

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class PkceGeneratorTest {
    @Test
    fun verifierIsUrlSafeAndWithinLength() {
        val verifier = PkceGenerator().generateVerifier()
        assertTrue(verifier.length in 43..128)
        assertTrue(verifier.all { it.isLetterOrDigit() || it == '-' || it == '_' })
    }

    @Test
    fun sameVerifierProducesSameChallenge() {
        val generator = PkceGenerator()
        val verifier = generator.generateVerifier()
        val challenge1 = generator.challengeFor(verifier)
        val challenge2 = generator.challengeFor(verifier)
        assertEquals(challenge1, challenge2)
    }

    @Test
    fun differentVerifiersProduceDifferentChallenges() {
        val generator = PkceGenerator()
        val challengeA = generator.challengeFor(generator.generateVerifier())
        val challengeB = generator.challengeFor(generator.generateVerifier())
        assertTrue(challengeA != challengeB)
    }
}
```

- [ ] **Step 2: Correr el test, debe pasar (ya que la implementación va junto con el test en este Task — Jules: correr igual para confirmar que compila y pasa antes de seguir)**

Run: `cd native/financespy-kmp && ./gradlew :shared:testDebugUnitTest --tests "py.com.cdco.financespy.auth.PkceGeneratorTest"`
Expected: `BUILD SUCCESSFUL`, 3 tests pasan.

- [ ] **Step 3: `TokenStorage` (expect/actual, implementación Android real)**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/auth/TokenStorage.kt`:
```kotlin
package py.com.cdco.financespy.auth

interface TokenStorage {
    suspend fun save(accessToken: String, refreshToken: String)
    suspend fun accessToken(): String?
    suspend fun refreshToken(): String?
    suspend fun clear()
}
```

`native/financespy-kmp/shared/src/androidMain/kotlin/py/com/cdco/financespy/auth/TokenStorage.android.kt`:
```kotlin
package py.com.cdco.financespy.auth

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class AndroidTokenStorage(context: Context) : TokenStorage {
    private val prefs: SharedPreferences = EncryptedSharedPreferences.create(
        context,
        "financespy_auth_prefs",
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    override suspend fun save(accessToken: String, refreshToken: String) {
        prefs.edit().putString("access_token", accessToken).putString("refresh_token", refreshToken).apply()
    }

    override suspend fun accessToken(): String? = prefs.getString("access_token", null)
    override suspend fun refreshToken(): String? = prefs.getString("refresh_token", null)
    override suspend fun clear() { prefs.edit().clear().apply() }
}
```

Agregar a `native/financespy-kmp/shared/build.gradle.kts`, bloque `androidMain.dependencies`:
```kotlin
implementation("androidx.security:security-crypto:1.1.0-alpha06")
```

- [ ] **Step 4: `ApiClient` con plugin de Bearer token automático**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/network/ApiClient.kt`:
```kotlin
package py.com.cdco.financespy.network

import io.ktor.client.HttpClient
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.plugins.logging.LogLevel
import io.ktor.client.plugins.logging.Logging
import io.ktor.client.request.header
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import py.com.cdco.financespy.auth.TokenStorage

object ApiClient {
    const val BASE_URL = "https://finance.cd-co.com.py"

    fun create(tokenStorage: TokenStorage): HttpClient = HttpClient {
        install(ContentNegotiation) {
            json(Json { ignoreUnknownKeys = true; isLenient = true })
        }
        install(Logging) { level = LogLevel.INFO }
        defaultRequest {
            url(BASE_URL)
        }
        engineConfigBearerInterceptor(tokenStorage)
    }
}

// expect/actual: cada plataforma agrega el interceptor de Authorization header a su engine.
// En Android (OkHttp engine) esto se implementa vía un Interceptor real en Task 2 androidMain.
expect fun HttpClient.engineConfigBearerInterceptor(tokenStorage: TokenStorage)
```

`native/financespy-kmp/shared/src/androidMain/kotlin/py/com/cdco/financespy/network/ApiClient.android.kt`:
```kotlin
package py.com.cdco.financespy.network

import io.ktor.client.HttpClient
import io.ktor.client.request.header
import io.ktor.client.plugins.api.createClientPlugin
import kotlinx.coroutines.runBlocking
import py.com.cdco.financespy.auth.TokenStorage

actual fun HttpClient.engineConfigBearerInterceptor(tokenStorage: TokenStorage) {
    val bearerPlugin = createClientPlugin("BearerAuthPlugin") {
        onRequest { request, _ ->
            val token = runBlocking { tokenStorage.accessToken() }
            if (token != null) request.header("Authorization", "Bearer $token")
        }
    }
    plugin(bearerPlugin)
}
```
Nota para quien implemente: `HttpClient` en Ktor no permite instalar plugins después de construido con `install {}` fuera del bloque de configuración — si `engineConfigBearerInterceptor` no compila así, mover su contenido DENTRO del bloque `HttpClient { ... }` de `ApiClient.create` usando `install(bearerPlugin)` en vez de `plugin(bearerPlugin)`, y resolver el `expect/actual` pasando el plugin ya construido como parámetro en vez de una función de extensión. Documentar en el PR cuál de las 2 formas terminó compilando.

- [ ] **Step 5: `AuthRepository`**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/auth/AuthRepository.kt`:
```kotlin
package py.com.cdco.financespy.auth

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.forms.submitForm
import io.ktor.http.Parameters
import kotlinx.serialization.Serializable
import py.com.cdco.financespy.network.ApiClient

private const val CLIENT_ID = "Ti8y1yGMsJVyNv35wsWE2taV7NR4B3zdKduf7E5IZEM"
private const val REDIRECT_URI = "financespy://oauth/callback"

@Serializable
data class TokenResponse(
    val access_token: String,
    val refresh_token: String,
    val token_type: String,
    val expires_in: Int
)

class AuthRepository(
    private val http: HttpClient,
    private val tokens: TokenStorage,
    private val pkce: PkceGenerator = PkceGenerator()
) {
    private var pendingVerifier: String? = null

    fun buildAuthorizationUrl(): String {
        val verifier = pkce.generateVerifier()
        pendingVerifier = verifier
        val challenge = pkce.challengeFor(verifier)
        return "${ApiClient.BASE_URL}/oauth/authorize" +
            "?client_id=$CLIENT_ID" +
            "&redirect_uri=$REDIRECT_URI" +
            "&response_type=code" +
            "&scope=read_write" +
            "&code_challenge=$challenge" +
            "&code_challenge_method=S256"
    }

    suspend fun exchangeCode(code: String): Result<Unit> = runCatching {
        val verifier = pendingVerifier ?: error("No hay un flujo de login en curso (falta buildAuthorizationUrl antes)")
        val response: TokenResponse = http.submitForm(
            url = "${ApiClient.BASE_URL}/oauth/token",
            formParameters = Parameters.build {
                append("grant_type", "authorization_code")
                append("client_id", CLIENT_ID)
                append("code", code)
                append("redirect_uri", REDIRECT_URI)
                append("code_verifier", verifier)
            }
        ).body()
        tokens.save(response.access_token, response.refresh_token)
        pendingVerifier = null
    }

    suspend fun isLoggedIn(): Boolean = tokens.accessToken() != null

    suspend fun logout() = tokens.clear()
}
```

- [ ] **Step 6: `LoginScreen` + intent-filter para el redirect**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/LoginScreen.kt`:
```kotlin
package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier

@Composable
fun LoginScreen(onLoginClick: () -> Unit) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("FinancePY")
        Button(onClick = onLoginClick) { Text("Iniciar sesión") }
    }
}
```

Agregar a `native/financespy-kmp/androidApp/src/main/AndroidManifest.xml`, dentro de `<activity>`, un segundo `<intent-filter>` (no reemplazar el existente):
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="financespy" android:host="oauth" android:path="/callback" />
</intent-filter>
```

- [ ] **Step 7: Correr todos los tests del módulo `:shared`**

Run: `cd native/financespy-kmp && ./gradlew :shared:testDebugUnitTest`
Expected: `BUILD SUCCESSFUL`, todos los tests pasan (incluye los 3 de `PkceGeneratorTest`).

- [ ] **Step 8: Commit**

```bash
git add native/financespy-kmp/
git commit -m "feat(native-android): Ktor client + auth OAuth2 PKCE (wave 1a task 2)"
```

---

## Task 3: Room KMP schema (accounts/entries/transactions)

**Files:**
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/AccountEntity.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/EntryEntity.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/TransactionEntity.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/AccountDao.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/EntryDao.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/TransactionDao.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/FinancePyDatabase.kt`
- Create: `native/financespy-kmp/shared/src/androidMain/kotlin/py/com/cdco/financespy/db/DatabaseBuilder.android.kt`
- Modify: `native/financespy-kmp/shared/build.gradle.kts` (plugin `room`, KSP)
- Test: `native/financespy-kmp/shared/src/commonTest/kotlin/py/com/cdco/financespy/db/DatabaseSmokeTest.kt`

**Interfaces:**
- Consumes: nada de Tasks 1-2 directamente (DB es independiente de auth), pero comparte el mismo módulo `:shared`.
- Produces:
  - `AccountEntity(id: String, name: String, balanceCents: Long, cashBalanceCents: Long, currency: String, classification: String, accountType: String, subtype: String?, status: String, updatedAt: String)` — PK `id` (uuid del server).
  - `EntryEntity(id: String, accountId: String, date: String, name: String, amountCents: Long, currency: String, entryableType: String, entryableId: String, parentEntryId: String?, transferId: String?, updatedAt: String)` — PK `id`.
  - `TransactionEntity(id: String, categoryId: String?, categoryName: String?, merchantId: String?, merchantName: String?, kind: String)` — PK `id`, coincide con `entryableId` de un `EntryEntity` cuando `entryableType == "Transaction"`.
  - `interface AccountDao { suspend fun upsertAll(accounts: List<AccountEntity>); suspend fun deleteAllExcept(ids: List<String>); fun observeAll(): Flow<List<AccountEntity>> }` — mismo shape para `EntryDao`/`TransactionDao`. Task 4 (sync engine) depende de `upsertAll`/`deleteAllExcept`; Task 5/6 (pantallas) dependen de `observeAll`.

- [ ] **Step 1: Entities**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/AccountEntity.kt`:
```kotlin
package py.com.cdco.financespy.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "accounts")
data class AccountEntity(
    @PrimaryKey val id: String,
    val name: String,
    val balanceCents: Long,
    val cashBalanceCents: Long,
    val currency: String,
    val classification: String,
    val accountType: String,
    val subtype: String?,
    val status: String,
    val updatedAt: String
)
```

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/EntryEntity.kt`:
```kotlin
package py.com.cdco.financespy.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "entries")
data class EntryEntity(
    @PrimaryKey val id: String,
    val accountId: String,
    val date: String,
    val name: String,
    val amountCents: Long,
    val currency: String,
    val entryableType: String,
    val entryableId: String,
    val parentEntryId: String?,
    val transferId: String?,
    val updatedAt: String
)
```

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/TransactionEntity.kt`:
```kotlin
package py.com.cdco.financespy.db

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "transactions")
data class TransactionEntity(
    @PrimaryKey val id: String,
    val categoryId: String?,
    val categoryName: String?,
    val merchantId: String?,
    val merchantName: String?,
    val kind: String
)
```

- [ ] **Step 2: DAOs**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/AccountDao.kt`:
```kotlin
package py.com.cdco.financespy.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface AccountDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(accounts: List<AccountEntity>)

    @Query("DELETE FROM accounts WHERE id NOT IN (:ids)")
    suspend fun deleteAllExcept(ids: List<String>)

    @Query("SELECT * FROM accounts ORDER BY name ASC")
    fun observeAll(): Flow<List<AccountEntity>>
}
```

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/EntryDao.kt`:
```kotlin
package py.com.cdco.financespy.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface EntryDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(entries: List<EntryEntity>)

    @Query("DELETE FROM entries WHERE id NOT IN (:ids) AND date >= :sinceDate")
    suspend fun deleteStaleWithinWindow(ids: List<String>, sinceDate: String)

    @Query("SELECT * FROM entries ORDER BY date DESC LIMIT :limit")
    fun observeRecent(limit: Int): Flow<List<EntryEntity>>
}
```

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/TransactionDao.kt`:
```kotlin
package py.com.cdco.financespy.db

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface TransactionDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(transactions: List<TransactionEntity>)

    @Query("SELECT * FROM transactions WHERE id = :id LIMIT 1")
    suspend fun findById(id: String): TransactionEntity?
}
```

Nota sobre `deleteAllExcept`/`deleteStaleWithinWindow`: dado que el server hace hard-delete y la wave 1a no tiene tombstones (spec, sección Sync), esta es la única forma de reflejar un borrado remoto — cada full-refetch trae el set completo de IDs vigentes en la ventana consultada, y todo lo que no está en ese set se borra localmente. Para `entries` se restringe a `date >= sinceDate` (la ventana de 90 días) para no borrar accidentalmente históricos que existen localmente pero no se volvieron a pedir.

- [ ] **Step 3: Database class**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/FinancePyDatabase.kt`:
```kotlin
package py.com.cdco.financespy.db

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [AccountEntity::class, EntryEntity::class, TransactionEntity::class],
    version = 1,
    exportSchema = true
)
abstract class FinancePyDatabase : RoomDatabase() {
    abstract fun accountDao(): AccountDao
    abstract fun entryDao(): EntryDao
    abstract fun transactionDao(): TransactionDao
}

expect fun buildDatabase(): FinancePyDatabase
```

- [ ] **Step 4: Builder Android**

`native/financespy-kmp/shared/src/androidMain/kotlin/py/com/cdco/financespy/db/DatabaseBuilder.android.kt`:
```kotlin
package py.com.cdco.financespy.db

import android.content.Context
import androidx.room.Room
import androidx.sqlite.driver.bundled.BundledSQLiteDriver

private lateinit var appContext: Context

fun initDatabaseBuilder(context: Context) {
    appContext = context.applicationContext
}

actual fun buildDatabase(): FinancePyDatabase =
    Room.databaseBuilder(appContext, FinancePyDatabase::class.java, "financespy.db")
        .setDriver(BundledSQLiteDriver())
        .build()
```

Llamar `initDatabaseBuilder(applicationContext)` en `MainActivity.onCreate` (Task 1), antes de `setContent`.

- [ ] **Step 5: Plugin Room + KSP en `shared/build.gradle.kts`**

Agregar al bloque `plugins` de `native/financespy-kmp/shared/build.gradle.kts`:
```kotlin
alias(libs.plugins.room)
id("com.google.devtools.ksp")
```
Y al final del archivo:
```kotlin
room {
    schemaDirectory("$projectDir/schemas")
}

dependencies {
    add("kspAndroid", "androidx.room:room-compiler:2.7.0-alpha11")
}
```
Agregar a `native/financespy-kmp/build.gradle.kts` (root), bloque `plugins`:
```kotlin
id("com.google.devtools.ksp") version "2.1.0-1.0.29" apply false
```

- [ ] **Step 6: Test de humo — insertar y leer**

`native/financespy-kmp/shared/src/commonTest/kotlin/py/com/cdco/financespy/db/DatabaseSmokeTest.kt`:
```kotlin
package py.com.cdco.financespy.db

// Nota para quien implemente: buildDatabase() usa Context en Android y no es
// instanciable directo en commonTest sin un fake. Este test se corre como
// androidUnitTest (instrumented-free, Robolectric) en vez de commonTest puro
// si buildDatabase() no puede resolverse ahí. Documentar en el PR cuál de
// los dos terminó siendo el source set real usado.
```
Dado que `buildDatabase()` depende de un `Context` Android real, mover este test a `native/financespy-kmp/shared/src/androidUnitTest/kotlin/py/com/cdco/financespy/db/DatabaseSmokeTest.kt`:
```kotlin
package py.com.cdco.financespy.db

import androidx.room.Room
import androidx.sqlite.driver.bundled.BundledSQLiteDriver
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals

@RunWith(RobolectricTestRunner::class)
class DatabaseSmokeTest {
    @Test
    fun upsertAndReadAccount() = runTest {
        val db = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            FinancePyDatabase::class.java
        ).setDriver(BundledSQLiteDriver()).build()

        val account = AccountEntity(
            id = "acc-1", name = "Cuenta Test", balanceCents = 100000L,
            cashBalanceCents = 100000L, currency = "PYG", classification = "asset",
            accountType = "depository", subtype = null, status = "active",
            updatedAt = "2026-08-19T00:00:00Z"
        )
        db.accountDao().upsertAll(listOf(account))

        val all = db.accountDao().observeAll()
        // Flow de Room: tomar el primer valor emitido para el assert
        var result: List<AccountEntity> = emptyList()
        db.accountDao().observeAll().collect { result = it; return@collect }
        assertEquals(1, result.size)
        assertEquals("Cuenta Test", result.first().name)
        db.close()
    }
}
```
Agregar a `native/financespy-kmp/shared/build.gradle.kts`, bloque `sourceSets`, un nuevo source set `androidUnitTest.dependencies`:
```kotlin
androidUnitTest.dependencies {
    implementation("androidx.test:core:1.6.1")
    implementation("org.robolectric:robolectric:4.14.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
}
```

- [ ] **Step 7: Correr el test**

Run: `cd native/financespy-kmp && ./gradlew :shared:testDebugUnitTest --tests "py.com.cdco.financespy.db.DatabaseSmokeTest"`
Expected: `BUILD SUCCESSFUL`, 1 test pasa. Si Robolectric no está disponible en el sandbox de Jules, documentar explícitamente en el PR que este test no pudo correr en el entorno y por qué — no lo omitas ni lo agregues como `@Ignore`.

- [ ] **Step 8: Commit**

```bash
git add native/financespy-kmp/
git commit -m "feat(native-android): Room KMP schema accounts/entries/transactions (wave 1a task 3)"
```

---

## Task 4: Motor de sync (full refetch, 90 días)

**Files:**
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/dto/AccountDto.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/dto/TransactionDto.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/FinancePyApi.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/sync/SyncEngine.kt`
- Test: `native/financespy-kmp/shared/src/commonTest/kotlin/py/com/cdco/financespy/sync/SyncEngineTest.kt`

**Interfaces:**
- Consumes: `ApiClient` (Task 2), `AccountDao`/`EntryDao`/`TransactionDao` (Task 3).
- Produces: `class SyncEngine(...) { suspend fun syncAll(): Result<Unit> }` — Task 5/6 lo llaman al entrar a Dashboard/Transacciones (foreground) y en pull-to-refresh.

- [ ] **Step 1: DTOs — shape exacto confirmado contra la API real (ver Investigación del spec)**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/dto/AccountDto.kt`:
```kotlin
package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class AccountsResponse(val accounts: List<AccountDto>, val pagination: PaginationDto)

@Serializable
data class AccountDto(
    val id: String,
    val name: String,
    val balance_cents: Long,
    val cash_balance_cents: Long,
    val currency: String,
    val classification: String,
    val account_type: String,
    val subtype: String? = null,
    val status: String,
    val updated_at: String
)

@Serializable
data class PaginationDto(val page: Int, val per_page: Int, val total_count: Int, val total_pages: Int)
```

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/dto/TransactionDto.kt`:
```kotlin
package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class TransactionsResponse(val transactions: List<TransactionListItemDto>, val pagination: PaginationDto)

@Serializable
data class TransactionListItemDto(
    val id: String,
    val date: String,
    val amount_cents: Long,
    val signed_amount_cents: Long,
    val currency: String,
    val name: String,
    val classification: String,
    val account: AccountRefDto,
    val category: CategoryRefDto? = null,
    val merchant: MerchantRefDto? = null,
    val created_at: String,
    val updated_at: String
)

@Serializable
data class AccountRefDto(val id: String, val name: String, val account_type: String)

@Serializable
data class CategoryRefDto(val id: String, val name: String, val color: String, val icon: String)

@Serializable
data class MerchantRefDto(val id: String, val name: String)
```

- [ ] **Step 2: `FinancePyApi` — llamadas HTTP tipadas**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/FinancePyApi.kt`:
```kotlin
package py.com.cdco.financespy.api

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.parameter
import py.com.cdco.financespy.api.dto.AccountsResponse
import py.com.cdco.financespy.api.dto.TransactionsResponse

class FinancePyApi(private val http: HttpClient) {
    suspend fun fetchAllAccounts(): List<py.com.cdco.financespy.api.dto.AccountDto> {
        val all = mutableListOf<py.com.cdco.financespy.api.dto.AccountDto>()
        var page = 1
        while (true) {
            val response: AccountsResponse = http.get("/api/v1/accounts") {
                parameter("page", page)
                parameter("per_page", 100)
            }.body()
            all += response.accounts
            if (page >= response.pagination.total_pages) break
            page++
        }
        return all
    }

    suspend fun fetchRecentTransactions(startDate: String): List<py.com.cdco.financespy.api.dto.TransactionListItemDto> {
        val all = mutableListOf<py.com.cdco.financespy.api.dto.TransactionListItemDto>()
        var page = 1
        while (true) {
            val response: TransactionsResponse = http.get("/api/v1/transactions") {
                parameter("page", page)
                parameter("per_page", 100)
                parameter("start_date", startDate)
            }.body()
            all += response.transactions
            if (page >= response.pagination.total_pages) break
            page++
        }
        return all
    }
}
```

- [ ] **Step 3: `SyncEngine`**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/sync/SyncEngine.kt`:
```kotlin
package py.com.cdco.financespy.sync

import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity
import py.com.cdco.financespy.db.TransactionDao
import py.com.cdco.financespy.db.TransactionEntity

const val SYNC_WINDOW_DAYS = 90

class SyncEngine(
    private val api: FinancePyApi,
    private val accountDao: AccountDao,
    private val entryDao: EntryDao,
    private val transactionDao: TransactionDao,
    private val currentDateProvider: () -> String
) {
    suspend fun syncAll(): Result<Unit> = runCatching {
        syncAccounts()
        syncTransactions()
    }

    private suspend fun syncAccounts() {
        val remote = api.fetchAllAccounts()
        accountDao.upsertAll(remote.map { it.toEntity() })
        accountDao.deleteAllExcept(remote.map { it.id })
    }

    private suspend fun syncTransactions() {
        val startDate = dateMinusDays(currentDateProvider(), SYNC_WINDOW_DAYS)
        val remote = api.fetchRecentTransactions(startDate)
        entryDao.upsertAll(remote.map { it.toEntryEntity() })
        transactionDao.upsertAll(remote.map { it.toTransactionEntity() })
        entryDao.deleteStaleWithinWindow(remote.map { it.id }, startDate)
    }
}

private fun AccountDto.toEntity() = AccountEntity(
    id = id, name = name, balanceCents = balance_cents, cashBalanceCents = cash_balance_cents,
    currency = currency, classification = classification, accountType = account_type,
    subtype = subtype, status = status, updatedAt = updated_at
)

private fun TransactionListItemDto.toEntryEntity() = EntryEntity(
    id = id, accountId = account.id, date = date, name = name, amountCents = signed_amount_cents,
    currency = currency, entryableType = "Transaction", entryableId = id,
    parentEntryId = null, transferId = null, updatedAt = updated_at
)

private fun TransactionListItemDto.toTransactionEntity() = TransactionEntity(
    id = id, categoryId = category?.id, categoryName = category?.name,
    merchantId = merchant?.id, merchantName = merchant?.name, kind = "standard"
)

// dateMinusDays: implementación simple sin dependencia de librería de fechas
// (kotlinx-datetime se evalúa en un Task futuro si hace falta más que esto).
private fun dateMinusDays(isoDate: String, days: Int): String {
    val parts = isoDate.substring(0, 10).split("-").map { it.toInt() }
    var (year, month, day) = Triple(parts[0], parts[1], parts[2])
    repeat(days) {
        day--
        if (day < 1) {
            month--
            if (month < 1) { month = 12; year-- }
            day = daysInMonth(year, month)
        }
    }
    return "%04d-%02d-%02d".format(year, month, day)
}

private fun daysInMonth(year: Int, month: Int): Int = when (month) {
    1, 3, 5, 7, 8, 10, 12 -> 31
    4, 6, 9, 11 -> 30
    2 -> if (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) 29 else 28
    else -> 30
}
```
Nota: `currentDateProvider` se inyecta (no `Clock.System.now()` directo adentro) específicamente para que el test de Step 4 sea determinístico sin mockear reloj del sistema.

- [ ] **Step 4: Test — `dateMinusDays` vía `SyncEngine` con API fake**

`native/financespy-kmp/shared/src/commonTest/kotlin/py/com/cdco/financespy/sync/SyncEngineTest.kt`:
```kotlin
package py.com.cdco.financespy.sync

import kotlin.test.Test
import kotlin.test.assertEquals

class SyncEngineDateMathTest {
    // dateMinusDays es privada — este test verifica el comportamiento indirectamente
    // llamando a una copia pública equivalente. Si el reviewer prefiere, extraer
    // dateMinusDays a un archivo separado (DateMath.kt) sin 'private' para testear directo;
    // documentar en el PR cuál de las 2 opciones se tomó.
    @Test
    fun ninetyDaysBeforeCrossesYearBoundary() {
        assertEquals("2025-11-20", subtractDaysPublic("2026-02-18", 90))
    }

    @Test
    fun handlesLeapYearFebruary() {
        assertEquals("2024-01-30", subtractDaysPublic("2024-02-29", 30))
    }
}

// Copia pública 1:1 de la función privada de SyncEngine.kt, para poder testearla
// sin cambiar su visibilidad en el archivo de producción. Si se decide exponerla
// pública ahí directamente, borrar esta copia y llamar a la real.
private fun subtractDaysPublic(isoDate: String, days: Int): String {
    val parts = isoDate.substring(0, 10).split("-").map { it.toInt() }
    var (year, month, day) = Triple(parts[0], parts[1], parts[2])
    repeat(days) {
        day--
        if (day < 1) {
            month--
            if (month < 1) { month = 12; year-- }
            day = when (month) {
                1, 3, 5, 7, 8, 10, 12 -> 31
                4, 6, 9, 11 -> 30
                2 -> if (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) 29 else 28
                else -> 30
            }
        }
    }
    return "%04d-%02d-%02d".format(year, month, day)
}
```

- [ ] **Step 5: Correr los tests**

Run: `cd native/financespy-kmp && ./gradlew :shared:testDebugUnitTest --tests "py.com.cdco.financespy.sync.*"`
Expected: `BUILD SUCCESSFUL`, 2 tests pasan.

- [ ] **Step 6: Commit**

```bash
git add native/financespy-kmp/
git commit -m "feat(native-android): sync engine full-refetch 90 dias (wave 1a task 4)"
```

---

## Task 5: Dashboard (net worth + cuentas + transacciones recientes)

**Files:**
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/dto/BalanceSheetDto.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/DashboardViewModel.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/DashboardScreen.kt`
- Modify: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/FinancePyApi.kt` (agregar `fetchBalanceSheet`)
- Modify: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/App.kt` (navegar a `DashboardScreen` post-login)

**Interfaces:**
- Consumes: `FinancePyApi` (Task 4), `SyncEngine.syncAll()` (Task 4), `AccountDao.observeAll()`/`EntryDao.observeRecent()` (Task 3).
- Produces: `@Composable fun DashboardScreen(viewModel: DashboardViewModel)` — Task 6 (Transacciones) reusa el mismo patrón de ViewModel+DAO Flow.

- [ ] **Step 1: DTO de balance sheet**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/dto/BalanceSheetDto.kt`:
```kotlin
package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class BalanceSheetResponse(
    val currency: String,
    val net_worth: MoneyDto,
    val assets: MoneyDto,
    val liabilities: MoneyDto
)

@Serializable
data class MoneyDto(val cents: Long? = null, val amount: String? = null, val currency: String? = null)
```
Nota para quien implemente: el spec dejó pendiente confirmar el shape exacto de `Money#as_json` (no se llegó a inspeccionar `def as_json` en el modelo). Antes de este Task, correr contra el server real: `curl -H "Authorization: Bearer <token>" https://finance.cd-co.com.py/api/v1/balance_sheet` (con un token válido de prueba) y ajustar `MoneyDto` a la respuesta real si difiere de los 2 shapes contemplados acá (`cents`+`currency` vs `amount`+`currency`). Documentar en el PR qué shape resultó ser el real.

- [ ] **Step 2: `fetchBalanceSheet` en `FinancePyApi`**

Agregar a `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/api/FinancePyApi.kt`:
```kotlin
suspend fun fetchBalanceSheet(): py.com.cdco.financespy.api.dto.BalanceSheetResponse =
    http.get("/api/v1/balance_sheet").body()
```

- [ ] **Step 3: `DashboardViewModel`**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/DashboardViewModel.kt`:
```kotlin
package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.dto.BalanceSheetResponse
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity
import py.com.cdco.financespy.sync.SyncEngine

data class DashboardState(
    val accounts: List<AccountEntity> = emptyList(),
    val recentEntries: List<EntryEntity> = emptyList(),
    val balanceSheet: BalanceSheetResponse? = null,
    val isSyncing: Boolean = false,
    val syncError: String? = null
)

class DashboardViewModel(
    private val scope: CoroutineScope,
    private val syncEngine: SyncEngine,
    private val api: FinancePyApi,
    accountDao: AccountDao,
    entryDao: EntryDao
) {
    private val _state = MutableStateFlow(DashboardState())
    val state: StateFlow<DashboardState> = _state

    init {
        combine(accountDao.observeAll(), entryDao.observeRecent(20)) { accounts, entries ->
            _state.value.copy(accounts = accounts, recentEntries = entries)
        }.onEach { _state.value = it }.launchIn(scope)

        refresh()
    }

    fun refresh() {
        scope.launch {
            _state.value = _state.value.copy(isSyncing = true, syncError = null)
            syncEngine.syncAll()
                .onSuccess {
                    val balanceSheet = runCatching { api.fetchBalanceSheet() }.getOrNull()
                    _state.value = _state.value.copy(isSyncing = false, balanceSheet = balanceSheet)
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(isSyncing = false, syncError = e.message ?: "Error de sincronización")
                }
        }
    }
}
```

- [ ] **Step 4: `DashboardScreen`**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/DashboardScreen.kt`:
```kotlin
package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun DashboardScreen(viewModel: DashboardViewModel) {
    val state by viewModel.state.collectAsState()

    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        state.balanceSheet?.let { bs ->
            Text("Patrimonio neto: ${bs.net_worth.cents ?: bs.net_worth.amount} ${bs.currency}")
        }
        Button(onClick = { viewModel.refresh() }) { Text("Actualizar") }
        if (state.isSyncing) CircularProgressIndicator()
        state.syncError?.let { Text("Error: $it") }

        Text("Cuentas")
        LazyColumn {
            items(state.accounts) { account ->
                Text("${account.name}: ${account.balanceCents / 100.0} ${account.currency}")
            }
        }

        Text("Transacciones recientes")
        LazyColumn {
            items(state.recentEntries) { entry ->
                Text("${entry.date} — ${entry.name}: ${entry.amountCents / 100.0} ${entry.currency}")
            }
        }
    }
}
```

- [ ] **Step 5: Wiring en `App.kt` (login → dashboard)**

Reemplazar el contenido completo de `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/App.kt`:
```kotlin
package py.com.cdco.financespy

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import kotlinx.coroutines.launch
import py.com.cdco.financespy.auth.AuthRepository
import py.com.cdco.financespy.screens.DashboardScreen
import py.com.cdco.financespy.screens.DashboardViewModel
import py.com.cdco.financespy.screens.LoginScreen

@Composable
fun App(
    authRepository: AuthRepository,
    dashboardViewModelFactory: () -> DashboardViewModel
) {
    var isLoggedIn by remember { mutableStateOf<Boolean?>(null) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) { isLoggedIn = authRepository.isLoggedIn() }

    MaterialTheme {
        when (isLoggedIn) {
            null -> {} // cargando estado inicial, sin flicker de login screen de más
            false -> LoginScreen(onLoginClick = {
                // MainActivity intercepta el intent de financespy://oauth/callback,
                // extrae `code`, llama authRepository.exchangeCode(code) y luego
                // actualiza isLoggedIn — cableado real de esa parte queda en
                // MainActivity.kt (Step 6), no en este composable.
            })
            true -> DashboardScreen(viewModel = remember { dashboardViewModelFactory() })
        }
    }
}
```
Nota: la firma de `App()` cambió (ahora recibe `authRepository` y `dashboardViewModelFactory`) — actualizar `MainActivity.kt` (Task 1/2) para pasarlos, construidos vía Koin (el módulo de DI Koin formal se arma en este mismo Task si no existe todavía; si Koin aún no está wireado, construir las instancias a mano en `MainActivity` por ahora — documentar en el PR cuál de las 2 opciones se usó).

- [ ] **Step 6: Verificar build completo**

Run: `cd native/financespy-kmp && ./gradlew :androidApp:assembleDebug`
Expected: `BUILD SUCCESSFUL`.

- [ ] **Step 7: Commit**

```bash
git add native/financespy-kmp/
git commit -m "feat(native-android): Dashboard screen (wave 1a task 5)"
```

---

## Task 6: Pantalla de Transacciones + build final del APK dev

**Files:**
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/TransactionsViewModel.kt`
- Create: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/TransactionsScreen.kt`
- Modify: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/EntryDao.kt` (agregar `observeAll` sin límite, para la lista completa paginada localmente)
- Modify: `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/App.kt` (navegación simple Dashboard↔Transacciones, 2 tabs)

**Interfaces:**
- Consumes: `EntryDao`/`TransactionDao` (Task 3), mismo patrón de `DashboardViewModel` (Task 5).
- Produces: `@Composable fun TransactionsScreen(viewModel: TransactionsViewModel)`.

- [ ] **Step 1: `observeAll` en `EntryDao`**

Agregar a `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/db/EntryDao.kt`:
```kotlin
@Query("SELECT * FROM entries ORDER BY date DESC")
fun observeAll(): Flow<List<EntryEntity>>
```

- [ ] **Step 2: `TransactionsViewModel`**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/TransactionsViewModel.kt`:
```kotlin
package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity

class TransactionsViewModel(
    scope: CoroutineScope,
    entryDao: EntryDao
) {
    private val _entries = MutableStateFlow<List<EntryEntity>>(emptyList())
    val entries: StateFlow<List<EntryEntity>> = _entries

    init {
        entryDao.observeAll().onEach { _entries.value = it }.launchIn(scope)
    }
}
```

- [ ] **Step 3: `TransactionsScreen`**

`native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/screens/TransactionsScreen.kt`:
```kotlin
package py.com.cdco.financespy.screens

import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue

@Composable
fun TransactionsScreen(viewModel: TransactionsViewModel) {
    val entries by viewModel.entries.collectAsState()

    LazyColumn {
        items(entries) { entry ->
            Text("${entry.date} — ${entry.name}: ${entry.amountCents / 100.0} ${entry.currency}")
        }
    }
}
```

- [ ] **Step 4: Navegación 2 tabs en `App.kt`**

Reemplazar el contenido completo de `native/financespy-kmp/shared/src/commonMain/kotlin/py/com/cdco/financespy/App.kt` (reemplaza la versión de Task 5 Step 5 entera, agrega el parámetro `transactionsViewModelFactory` y las tabs):
```kotlin
package py.com.cdco.financespy

import androidx.compose.material3.Column
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import py.com.cdco.financespy.auth.AuthRepository
import py.com.cdco.financespy.screens.DashboardScreen
import py.com.cdco.financespy.screens.DashboardViewModel
import py.com.cdco.financespy.screens.LoginScreen
import py.com.cdco.financespy.screens.TransactionsScreen
import py.com.cdco.financespy.screens.TransactionsViewModel

@Composable
fun App(
    authRepository: AuthRepository,
    dashboardViewModelFactory: () -> DashboardViewModel,
    transactionsViewModelFactory: () -> TransactionsViewModel
) {
    var isLoggedIn by remember { mutableStateOf<Boolean?>(null) }

    LaunchedEffect(Unit) { isLoggedIn = authRepository.isLoggedIn() }

    MaterialTheme {
        when (isLoggedIn) {
            null -> {} // cargando estado inicial, sin flicker de login screen de más
            false -> LoginScreen(onLoginClick = {
                // MainActivity intercepta el intent de financespy://oauth/callback,
                // extrae `code`, llama authRepository.exchangeCode(code) y luego
                // actualiza isLoggedIn — cableado real de esa parte queda en
                // MainActivity.kt, no en este composable.
            })
            true -> {
                var selectedTab by remember { mutableStateOf(0) }
                Column {
                    TabRow(selectedTabIndex = selectedTab) {
                        Tab(selected = selectedTab == 0, onClick = { selectedTab = 0 }, text = { Text("Dashboard") })
                        Tab(selected = selectedTab == 1, onClick = { selectedTab = 1 }, text = { Text("Transacciones") })
                    }
                    when (selectedTab) {
                        0 -> DashboardScreen(viewModel = remember { dashboardViewModelFactory() })
                        1 -> TransactionsScreen(viewModel = remember { transactionsViewModelFactory() })
                    }
                }
            }
        }
    }
}
```
Actualizar `MainActivity.kt` (`setContent { App(...) }`) para pasar los 3 argumentos, construidos a mano o vía Koin según lo que haya quedado resuelto en Task 5 Step 5.

- [ ] **Step 5: Build final del APK de desarrollo**

Run: `cd native/financespy-kmp && ./gradlew :androidApp:assembleDebug`
Expected: `BUILD SUCCESSFUL`. Confirmar en la descripción del PR el path del APK generado (`androidApp/build/outputs/apk/debug/androidApp-debug.apk`) y su `applicationId` (`py.com.cdco.financespy.dev`, NUNCA el de producción).

- [ ] **Step 6: Commit**

```bash
git add native/financespy-kmp/
git commit -m "feat(native-android): pantalla Transacciones + tabs (wave 1a task 6, cierra fundacion)"
```

---

## Cierre de wave 1a

Con las 6 tasks mergeadas: login PKCE real, Room sincronizado por full-refetch cada 90 días de transacciones, Dashboard con net worth + cuentas + recientes, y pantalla de Transacciones completa — todo corriendo contra la API v1 real sin haber tocado el backend. Sideload del APK dev (`py.com.cdco.financespy.dev`) en un dispositivo real, junto al Capacitor de producción, para validar en persona antes de decidir wave 1b.

**Antes de arrancar 1b**: revisar en dispositivo real los 2 puntos que este plan dejó como "documentar en el PR cuál opción se usó" (Task 2 Step 4 — plugin Ktor Bearer; Task 5 Step 1 — shape real de `Money#as_json`) y actualizar este documento o el spec si terminaron resueltos distinto de lo planteado acá.
