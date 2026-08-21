# Unificación móvil FinancePY (Capacitor + captura Wallet) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Portar la captura de notificaciones Wallet (RN app `financespy-app`) a la app Capacitor ya construida (`cd-co-erp`, rama `feature/android-offline-phase1`), como plugin nativo, para terminar con UNA sola app Android instalable en vez de tres iniciativas separadas.

**Architecture:** Servicio Android `NotificationListenerService` (Kotlin) sigue escuchando notificaciones de Wallet igual que en el RN app. Corrección respecto al spec de arquitectura original: la extracción de monto, el mapeo de tarjeta→cuenta, el POST al webhook y la cola de reintentos se implementan **enteramente en Kotlin nativo**, no en el JS de la WebView — porque el JS de esta app es el mismo bundle que sirve la web pública (`server.url` remoto), y poner ahí un bearer token fijo lo expondría a cualquier visitante del sitio, no solo al APK. El puente Capacitor (`WalletListenerPlugin`) solo expone a JS lo necesario para la UI de Settings: pedir permiso y consultar si está activado.

**Tech Stack:** Kotlin (Android nativo), Capacitor Plugin API, Ruby/ERB + Stimulus (UI de Settings existente).

## Global Constraints

- No se toca el backend Rails (`POST /webhooks/android_purchase`, token fijo) — contrato sin cambios, verificado en `docs/superpowers/plans/2026-07-28-android-purchase-webhook.md`.
- `android/` (raíz del repo `cd-co-erp`) está gitignoreado a propósito (`.gitignore:136`, "se puede regenerar en cualquier momento desde `capacitor.config.json`") — código nativo custom NO se edita ahí directamente, se versiona en `native/android/wallet-listener/` y se copia con un script (Tarea 1).
- Sin librerías nuevas de terceros para lógica de captura (extracción de monto, mapeo de cuenta) — se porta la lógica ya probada del RN app (`.worktrees/financespy-mobile-app/mobile/financespy-app/src/capture/`), no se reescribe desde cero.
- El proyecto `cd-co-erp` no tiene test runner de JS ni de Android configurado (sin bundler, todo JS por importmap; `android/` recién se genera en Tarea 1) — igual que el spec de la Fase 1 offline (`docs/superpowers/specs/2026-08-05-financespy-android-offline-design.md`), la verificación es manual en dispositivo real, no unit tests automatizados. Cada tarea define su paso de verificación manual explícito en vez de "escribir test".
- El token del webhook (`android_webhook_token.txt`, ya generado en una sesión previa) nunca se pega en código versionado ni en este plan — vive en `android/app/src/main/res/values/secrets.xml`, que queda dentro de `/android/` (ya gitignoreado) y se completa a mano en cada máquina, mismo patrón que `*.keystore`/`keystore.properties` (`.gitignore:141-143`).

---

### Task 1: Scaffold del proyecto Android nativo + script de enlace de código custom

**Files:**
- Create: `native/android/wallet-listener/.gitkeep` (placeholder hasta Tarea 2)
- Create: `bin/android_link_native.sh`
- Modify: `package.json:11-13` (agregar script `android:link-native`)
- Modify: `docs/CAPACITOR.md` (documentar el paso nuevo)

**Interfaces:**
- Produce: script `bin/android_link_native.sh` que las Tareas 2-3 van a extender (no solo ejecutar) para copiar Kotlin real dentro de `android/`.

- [ ] **Step 1: Crear rama de trabajo desde la base offline-first**

```bash
git checkout feature/android-offline-phase1
git pull origin feature/android-offline-phase1
git checkout -b feature/android-unified-wallet-capture
```

- [ ] **Step 2: Generar el proyecto Android nativo (si no existe ya localmente)**

```bash
npm install
npm run android:add
```

Expected: crea `./android/` con proyecto Gradle/Kotlin estándar (Capacitor). Si ya existe de un `cap add` previo, el comando no hace nada destructivo — Capacitor lo detecta y avisa.

- [ ] **Step 3: Crear el directorio versionado para código nativo custom**

```bash
mkdir -p native/android/wallet-listener
touch native/android/wallet-listener/.gitkeep
```

- [ ] **Step 4: Escribir el script de enlace**

```bash
#!/usr/bin/env bash
# bin/android_link_native.sh
#
# Copia el código nativo custom (versionado en native/android/wallet-listener/)
# dentro de android/, que Capacitor regenera y por eso está gitignoreado.
# Correr después de cada `npm run android:add` o `npm run android:sync`.
set -euo pipefail

PKG_DIR="android/app/src/main/java/py/com/cdco/financespy/wallet"
MAIN_ACTIVITY="android/app/src/main/java/py/com/cdco/financespy/MainActivity.kt"

mkdir -p "$PKG_DIR"
cp native/android/wallet-listener/*.kt "$PKG_DIR/"

REGISTER_LINE="        registerPlugin(WalletListenerPlugin::class.java)"
if ! grep -qF "$REGISTER_LINE" "$MAIN_ACTIVITY"; then
  echo "⚠️  Falta registrar el plugin en $MAIN_ACTIVITY — agregá esta línea"
  echo "    dentro de onCreate(), antes de super.onCreate(savedInstanceState):"
  echo "$REGISTER_LINE"
else
  echo "✅ Plugin ya registrado en MainActivity.kt"
fi

echo ""
echo "⚠️  Verificá manualmente que android/app/src/main/AndroidManifest.xml"
echo "    tenga el bloque de native/android/wallet-listener/manifest-snippet.xml"
echo "    (el merge de manifest no se automatiza acá, ver docs/CAPACITOR.md)"
```

```bash
chmod +x bin/android_link_native.sh
```

- [ ] **Step 5: Registrar el script en package.json**

Editar el bloque `"scripts"` de `package.json` (visto en la Tarea de research: líneas con `"android:add"`, `"android:sync"`, `"android:open"`):

```json
		"android:add": "cap add android",
		"android:sync": "cap sync android",
		"android:open": "cap open android",
		"android:link-native": "bash bin/android_link_native.sh"
```

- [ ] **Step 6: Documentar el paso en docs/CAPACITOR.md**

Agregar después de la sección "## Pasos" existente:

```markdown
## Código nativo custom (plugin Wallet Listener)

El plugin de captura de notificaciones Wallet vive versionado en
`native/android/wallet-listener/` (NO dentro de `android/`, que se regenera).
Después de `npm run android:add` o `npm run android:sync`, correr:

\`\`\`bash
npm run android:link-native
\`\`\`

Copia los `.kt` al proyecto generado y avisa si falta registrar el plugin en
`MainActivity.kt` o mergear `manifest-snippet.xml` en el `AndroidManifest.xml`
(esos dos pasos son manuales a propósito — automatizar un merge de XML/Kotlin
existente es más frágil que dejarlo explícito).
```

- [ ] **Step 7: Verificar y commitear**

```bash
git status
```
Expected: `native/android/wallet-listener/.gitkeep`, `bin/android_link_native.sh`, `package.json`, `docs/CAPACITOR.md` modificados/nuevos. `android/` NO debe aparecer (gitignoreado).

```bash
git add native/android/wallet-listener/.gitkeep bin/android_link_native.sh package.json docs/CAPACITOR.md
git commit -m "chore: scaffold Android nativo + script de enlace para plugin Wallet Listener"
```

---

### Task 2: Servicio Kotlin de escucha de notificaciones + extracción/mapeo

**Files:**
- Create: `native/android/wallet-listener/WalletNotificationListenerService.kt`
- Create: `native/android/wallet-listener/PurchaseExtractor.kt`
- Create: `native/android/wallet-listener/AccountMapping.kt`

**Interfaces:**
- Consume: nada (es la capa más baja).
- Produce: `WalletNotificationListenerService.listener: ((title: String, text: String) -> Unit)?` — callback estático que la Tarea 3 (`WalletListenerPlugin`) engancha. `PurchaseExtractor.extract(text: String): Purchase?` con `data class Purchase(val amount: String, val cardText: String)`. `AccountMapping.accountIdFor(cardText: String): String?`.

- [ ] **Step 1: Puerto de `extractPurchase.ts` a Kotlin**

Original (RN, TS puro, sin dependencias — portable literal):
```ts
const PURCHASE_PATTERN = /PYG([\d,]+) con (.+)/;
export function extractPurchase(notificationText: string) {
  const match = notificationText.match(PURCHASE_PATTERN);
  if (!match) return null;
  const [, amount, cardText] = match;
  return { amount, cardText: cardText.trim() };
}
```

```kotlin
// native/android/wallet-listener/PurchaseExtractor.kt
package py.com.cdco.financespy.wallet

data class Purchase(val amount: String, val cardText: String)

object PurchaseExtractor {
    private val PURCHASE_PATTERN = Regex("""PYG([\d,]+) con (.+)""")

    fun extract(notificationText: String): Purchase? {
        val match = PURCHASE_PATTERN.find(notificationText) ?: return null
        val (amount, cardText) = match.destructured
        return Purchase(amount, cardText.trim())
    }
}
```

- [ ] **Step 2: Puerto de `accountMapping.ts` a Kotlin (mismos IDs de cuenta reales)**

```kotlin
// native/android/wallet-listener/AccountMapping.kt
package py.com.cdco.financespy.wallet

object AccountMapping {
    private val CARD_TO_ACCOUNT_ID = mapOf(
        "Ueno" to "74fa6687-bbf7-45d2-aa71-f06bca3b2013",
        "Amex" to "d47f5223-a988-46f5-9bc5-beefc4c7fefd",
        "CLASICA" to "952d06b3-f915-4cf1-b4c2-952fb131f2be",
        "GNB" to "43d84b14-b3be-44a9-be37-7ec1ae4661f2"
    )

    fun accountIdFor(cardText: String): String? {
        return CARD_TO_ACCOUNT_ID.entries
            .firstOrNull { (substring, _) -> cardText.contains(substring, ignoreCase = true) }
            ?.value
    }
}
```

- [ ] **Step 3: Servicio de notificaciones (adaptado del original RN — sin dependencias de React Native)**

Original (RN, acopla directo al bridge de React Native vía `ReactApplication`/`DeviceEventManagerModule` — es exactamente lo que hay que reemplazar):
```kotlin
override fun onNotificationPosted(sbn: StatusBarNotification) {
    if (sbn.packageName != WALLET_PACKAGE) return
    val extras = sbn.notification.extras
    val title = extras.getCharSequence("android.title")?.toString() ?: ""
    val text = extras.getCharSequence("android.text")?.toString() ?: ""
    if (title.isEmpty() && text.isEmpty()) return
    val reactContext = (application as? ReactApplication)?.reactHost?.currentReactContext ?: return
    // ... emit vía RN bridge
}
```

```kotlin
// native/android/wallet-listener/WalletNotificationListenerService.kt
package py.com.cdco.financespy.wallet

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class WalletNotificationListenerService : NotificationListenerService() {
    companion object {
        const val WALLET_PACKAGE = "com.google.android.apps.walletnfcrel"
        // Enganchado por WalletListenerPlugin.load() — reemplaza el bridge de
        // React Native del original por un callback estático simple, porque
        // acá no hay ReactContext: es un plugin de Capacitor.
        var listener: ((title: String, text: String) -> Unit)? = null
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName != WALLET_PACKAGE) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        if (title.isEmpty() && text.isEmpty()) return

        listener?.invoke(title, text)
    }
}
```

- [ ] **Step 4: Verificación manual (sin test runner Android configurado — ver Global Constraints)**

```bash
npm run android:link-native
```
Expected: copia los 3 `.kt` a `android/app/src/main/java/py/com/cdco/financespy/wallet/`, imprime el aviso de registrar el plugin (todavía no existe — se crea en Tarea 3, es esperado en este punto).

- [ ] **Step 5: Commit**

```bash
git add native/android/wallet-listener/WalletNotificationListenerService.kt \
        native/android/wallet-listener/PurchaseExtractor.kt \
        native/android/wallet-listener/AccountMapping.kt
git commit -m "feat: portar listener de notificaciones Wallet + extracción/mapeo a Kotlin nativo"
```

---

### Task 3: Plugin Capacitor (permiso + estado) + cola de reintentos + POST al webhook

**Files:**
- Create: `native/android/wallet-listener/WalletListenerPlugin.kt`
- Create: `native/android/wallet-listener/PendingCaptureStore.kt`
- Create: `native/android/wallet-listener/WebhookClient.kt`
- Create: `native/android/wallet-listener/manifest-snippet.xml`
- Create: `android/app/src/main/res/values/secrets.xml` (NO versionado — dentro de `/android/`, ver Global Constraints)

**Interfaces:**
- Consume: `WalletNotificationListenerService.listener`, `PurchaseExtractor.extract`, `AccountMapping.accountIdFor` (Tarea 2).
- Produce: plugin JS-visible `WalletListener` con métodos `isListenerEnabled()`, `requestPermission()` y evento `walletNotification` — usado por la Tarea 4 (bridge JS) solo para UI, no para el POST real.

- [ ] **Step 1: Cola de reintentos en SharedPreferences (puerto de `pendingQueue.ts`, que usaba AsyncStorage — acá el equivalente nativo es SharedPreferences, no IndexedDB, porque esto vive fuera de la WebView)**

```kotlin
// native/android/wallet-listener/PendingCaptureStore.kt
package py.com.cdco.financespy.wallet

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class PendingCapture(
    val id: String,
    val capturedAt: String,
    val rawText: String,
    val accountId: String,
    val amount: String,
    val merchant: String,
    val item: String
)

class PendingCaptureStore(context: Context) {
    private val prefs = context.getSharedPreferences("wallet_listener_pending", Context.MODE_PRIVATE)
    private val KEY = "captures"

    fun add(capture: PendingCapture) {
        val all = readAll().toMutableList()
        all.add(capture)
        writeAll(all)
    }

    fun readAll(): List<PendingCapture> {
        val raw = prefs.getString(KEY, null) ?: return emptyList()
        val arr = JSONArray(raw)
        return (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i)
            PendingCapture(
                id = o.getString("id"),
                capturedAt = o.getString("capturedAt"),
                rawText = o.getString("rawText"),
                accountId = o.getString("accountId"),
                amount = o.getString("amount"),
                merchant = o.getString("merchant"),
                item = o.getString("item")
            )
        }
    }

    fun remove(id: String) {
        writeAll(readAll().filterNot { it.id == id })
    }

    private fun writeAll(captures: List<PendingCapture>) {
        val arr = JSONArray()
        captures.forEach { c ->
            arr.put(JSONObject().apply {
                put("id", c.id)
                put("capturedAt", c.capturedAt)
                put("rawText", c.rawText)
                put("accountId", c.accountId)
                put("amount", c.amount)
                put("merchant", c.merchant)
                put("item", c.item)
            })
        }
        prefs.edit().putString(KEY, arr.toString()).apply()
    }
}
```

- [ ] **Step 2: Cliente del webhook (puerto de `webhookClient.ts` — mismo endpoint, mismo contrato, POST nativo en vez de `fetch()` desde la WebView)**

Original (RN, para referencia del contrato — payload y URL no cambian):
```ts
const WEBHOOK_URL = 'https://finance.cd-co.com.py/webhooks/android_purchase';
// body: { account_id, amount, merchant, item, raw_text, timestamp }
// response.status 200/201 + body.duplicate: boolean
```

```kotlin
// native/android/wallet-listener/WebhookClient.kt
package py.com.cdco.financespy.wallet

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

sealed class WebhookResult {
    data class Success(val duplicate: Boolean) : WebhookResult()
    data class Failure(val error: String) : WebhookResult()
}

class WebhookClient(private val token: String) {
    private val url = "https://finance.cd-co.com.py/webhooks/android_purchase"

    fun post(capture: PendingCapture): WebhookResult {
        return try {
            val conn = URL(url).openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.setRequestProperty("Content-Type", "application/json")
            conn.doOutput = true
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000

            val body = JSONObject().apply {
                put("account_id", capture.accountId)
                put("amount", capture.amount)
                put("merchant", capture.merchant)
                put("item", capture.item)
                put("raw_text", capture.rawText)
                put("timestamp", capture.capturedAt)
            }
            conn.outputStream.use { it.write(body.toString().toByteArray()) }

            val status = conn.responseCode
            if (status == 200 || status == 201) {
                val respBody = conn.inputStream.bufferedReader().use { it.readText() }
                val duplicate = JSONObject(respBody).optBoolean("duplicate", false)
                WebhookResult.Success(duplicate)
            } else {
                WebhookResult.Failure("Unexpected status $status")
            }
        } catch (e: Exception) {
            WebhookResult.Failure(e.message ?: "Unknown network error")
        }
    }
}
```

- [ ] **Step 3: Plugin Capacitor — conecta el listener, expone permiso/estado a JS, y es quien orquesta extracción → mapeo → POST → cola**

```kotlin
// native/android/wallet-listener/WalletListenerPlugin.kt
package py.com.cdco.financespy.wallet

import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import java.util.UUID

@CapacitorPlugin(name = "WalletListener")
class WalletListenerPlugin : Plugin() {
    private lateinit var store: PendingCaptureStore

    override fun load() {
        store = PendingCaptureStore(context)

        WalletNotificationListenerService.listener = { title, text ->
            handleNotification(title, text)
        }
    }

    private fun handleNotification(title: String, text: String) {
        val purchase = PurchaseExtractor.extract(text) ?: return
        val accountId = AccountMapping.accountIdFor(purchase.cardText)
        val capturedAt = java.time.Instant.now().toString()

        val data = JSObject()
        data.put("merchant", title)
        data.put("amount", purchase.amount)
        data.put("cardText", purchase.cardText)

        if (accountId == null) {
            data.put("status", "unrecognized_card")
            notifyListeners("walletCapture", data)
            return
        }

        val capture = PendingCapture(
            id = UUID.randomUUID().toString(),
            capturedAt = capturedAt,
            rawText = text,
            accountId = accountId,
            amount = purchase.amount,
            merchant = title,
            item = purchase.cardText
        )

        val token = context.getString(
            context.resources.getIdentifier("wallet_webhook_token", "string", context.packageName)
        )
        val result = WebhookClient(token).post(capture)

        when (result) {
            is WebhookResult.Success -> {
                data.put("status", if (result.duplicate) "duplicate" else "created")
            }
            is WebhookResult.Failure -> {
                store.add(capture)
                data.put("status", "queued")
                data.put("error", result.error)
            }
        }
        notifyListeners("walletCapture", data)
    }

    @PluginMethod
    fun isListenerEnabled(call: PluginCall) {
        val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
        val enabled = !TextUtils.isEmpty(flat) && flat.contains(context.packageName)
        val ret = JSObject()
        ret.put("enabled", enabled)
        call.resolve(ret)
    }

    @PluginMethod
    fun requestPermission(call: PluginCall) {
        activity.startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"))
        call.resolve()
    }

    @PluginMethod
    fun pendingCount(call: PluginCall) {
        val ret = JSObject()
        ret.put("count", store.readAll().size)
        call.resolve(ret)
    }
}
```

- [ ] **Step 4: Manifest snippet (merge manual, ver Tarea 1 Step 4 — el script solo avisa, no lo aplica)**

```xml
<!-- native/android/wallet-listener/manifest-snippet.xml -->
<!-- Pegar dentro de <application> en android/app/src/main/AndroidManifest.xml -->
<service
    android:name="py.com.cdco.financespy.wallet.WalletNotificationListenerService"
    android:exported="false"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
    <intent-filter>
        <action android:name="android.service.notification.NotificationListenerService" />
    </intent-filter>
</service>
```

- [ ] **Step 5: Archivo de secreto local (NO versionado — plantilla documentada acá, valor real se completa a mano)**

```xml
<!-- android/app/src/main/res/values/secrets.xml -->
<!-- NO commitear con el valor real. Usar el mismo token ya generado para el -->
<!-- webhook (ver notas de la sesión que armó docs/superpowers/plans/2026-07-28-android-purchase-webhook.md). -->
<resources>
    <string name="wallet_webhook_token" translatable="false">PEGAR_TOKEN_REAL_ACA</string>
</resources>
```

- [ ] **Step 6: Verificación manual — build de compilación**

```bash
npm run android:link-native
npm run android:open
```
En Android Studio: **Build → Make Project**. Expected: compila sin errores. Si falta `secrets.xml`, falla con "resource wallet_webhook_token not found" — crear el archivo del Step 5 con el token real antes de reintentar.

- [ ] **Step 7: Commit (sin el secreto)**

```bash
git add native/android/wallet-listener/WalletListenerPlugin.kt \
        native/android/wallet-listener/PendingCaptureStore.kt \
        native/android/wallet-listener/WebhookClient.kt \
        native/android/wallet-listener/manifest-snippet.xml
git commit -m "feat: plugin Capacitor Wallet Listener — cola de reintentos + POST nativo al webhook"
```

---

### Task 4: Reintento de pendientes al reconectar + UI de Settings

**Files:**
- Modify: `native/android/wallet-listener/WalletListenerPlugin.kt` (agregar `retryPending()`)
- Create: `app/javascript/services/wallet_listener.js`
- Modify: `app/views/settings/preferences/show.html.erb`
- Modify: `config/locales/en.yml` y `config/locales/es.yml` (claves de traducción nuevas — verificar estructura real antes de editar, ver Step 3)

**Interfaces:**
- Consume: `WalletListener.isListenerEnabled()`, `WalletListener.requestPermission()`, `WalletListener.pendingCount()`, evento `walletCapture` (Tarea 3).
- Produce: `wallet_listener.js` exporta `isWalletListenerAvailable()`, `isWalletListenerEnabled()`, `requestWalletListenerPermission()`, `getPendingWalletCaptureCount()`, `onWalletCapture(handler)`.

- [ ] **Step 1: Reintento de pendientes en el plugin — se dispara al reconectar red (`onNetworkStateChanged` no existe en Capacitor core; se usa el broadcast de Android directamente ya que esto es 100% nativo)**

```kotlin
// Agregar a WalletListenerPlugin.kt, dentro de la clase:

@PluginMethod
fun retryPending(call: PluginCall) {
    val token = context.getString(
        context.resources.getIdentifier("wallet_webhook_token", "string", context.packageName)
    )
    val client = WebhookClient(token)
    var applied = 0

    store.readAll().forEach { capture ->
        when (val result = client.post(capture)) {
            is WebhookResult.Success -> {
                store.remove(capture.id)
                applied++
            }
            is WebhookResult.Failure -> {
                // se queda en la cola, se reintenta en la próxima llamada
            }
        }
    }

    val ret = JSObject()
    ret.put("applied", applied)
    call.resolve(ret)
}
```

- [ ] **Step 2: Bridge JS — mismo patrón que `app/javascript/services/offline_transactions_sync.js` (módulo ES plano, importmap, sin bundler)**

```js
// app/javascript/services/wallet_listener.js
//
// Puente al plugin nativo Capacitor "WalletListener" (native/android/wallet-listener/).
// Solo UI: permiso y estado. La captura, extracción, mapeo y POST al webhook
// pasan enteramente por Kotlin nativo — ver Global Constraints del plan de
// implementación (docs/superpowers/plans/2026-08-12-financespy-mobile-unificacion-capacitor.md)
// sobre por qué el token del webhook no puede tocar este bundle.

function plugin() {
  return window.Capacitor?.Plugins?.WalletListener ?? null;
}

export function isWalletListenerAvailable() {
  return !!plugin();
}

export async function isWalletListenerEnabled() {
  const p = plugin();
  if (!p) return false;
  const { enabled } = await p.isListenerEnabled();
  return enabled;
}

export async function requestWalletListenerPermission() {
  const p = plugin();
  if (!p) return;
  await p.requestPermission();
}

export async function getPendingWalletCaptureCount() {
  const p = plugin();
  if (!p) return 0;
  const { count } = await p.pendingCount();
  return count;
}

export async function retryPendingWalletCaptures() {
  const p = plugin();
  if (!p) return 0;
  const { applied } = await p.retryPending();
  return applied;
}

export function onWalletCapture(handler) {
  const p = plugin();
  if (!p) return () => {};
  const listenerPromise = p.addListener("walletCapture", handler);
  return () => listenerPromise.then((l) => l.remove());
}
```

- [ ] **Step 3: Verificar claves i18n existentes antes de agregar nuevas**

```bash
grep -n "preferences:" config/locales/es.yml | head -5
grep -n "general_title\|general_subtitle" config/locales/es.yml
```
Usar esos resultados para ubicar el nesting real bajo `settings.preferences` antes del Step 4 — el árbol exacto de `es.yml`/`en.yml` no se asume, se confirma con este grep porque son archivos generados/mantenidos por el equipo de i18n del fork y pueden diferir de lo esperado.

- [ ] **Step 4: Sección nueva en Settings → Preferences (sigue el patrón de `settings_section` ya usado en el mismo archivo, ver bloque `general_title` leído en la investigación de este plan)**

Agregar en `app/views/settings/preferences/show.html.erb`, antes del `<% if Current.user.admin? %>` final:

```erb
<%= settings_section title: t(".wallet_capture_title"), subtitle: t(".wallet_capture_subtitle") do %>
  <div data-controller="wallet-capture-settings">
    <div data-wallet-capture-settings-target="status" class="text-sm text-secondary">
      <%= t(".wallet_capture_checking") %>
    </div>
    <%= render DS::Button.new(
      text: t(".wallet_capture_enable"),
      type: :button,
      data: { action: "wallet-capture-settings#requestPermission" }
    ) %>
  </div>
<% end %>
```

- [ ] **Step 5: Stimulus controller — mismo patrón que `offline_transactions_controller.js` (Stimulus + módulos importmap)**

```js
// app/javascript/controllers/wallet_capture_settings_controller.js
import { Controller } from "@hotwired/stimulus";
import {
  isWalletListenerAvailable,
  isWalletListenerEnabled,
  requestWalletListenerPermission,
  getPendingWalletCaptureCount,
} from "services/wallet_listener";

export default class extends Controller {
  static targets = ["status"];

  async connect() {
    await this.refresh();
  }

  async refresh() {
    if (!isWalletListenerAvailable()) {
      this.statusTarget.textContent = "Disponible solo en la app Android.";
      return;
    }

    const enabled = await isWalletListenerEnabled();
    const pending = await getPendingWalletCaptureCount();

    this.statusTarget.textContent = enabled
      ? `Activado. ${pending} captura(s) pendiente(s) de sincronizar.`
      : "Desactivado — activá el acceso a notificaciones para capturar compras de Wallet automáticamente.";
  }

  async requestPermission() {
    await requestWalletListenerPermission();
    await this.refresh();
  }
}
```

- [ ] **Step 6: Traducciones (agregar bajo el nesting confirmado en Step 3)**

```yaml
# config/locales/es.yml — bajo settings > preferences > show
wallet_capture_title: "Captura automática de Wallet"
wallet_capture_subtitle: "Registrá compras pagadas con Google Wallet sin cargarlas a mano."
wallet_capture_checking: "Verificando estado..."
wallet_capture_enable: "Activar acceso a notificaciones"
```
```yaml
# config/locales/en.yml — mismo nesting
wallet_capture_title: "Automatic Wallet capture"
wallet_capture_subtitle: "Log Google Wallet purchases without entering them by hand."
wallet_capture_checking: "Checking status..."
wallet_capture_enable: "Enable notification access"
```

- [ ] **Step 7: Verificación manual**

```bash
npm run android:link-native
npm run android:open
```
En Android Studio, Run en dispositivo real: entrar a Settings → Preferences, confirmar que aparece la sección "Captura automática de Wallet" con el estado correcto y que el botón abre la pantalla nativa de Android para conceder acceso a notificaciones.

- [ ] **Step 8: Commit**

```bash
git add native/android/wallet-listener/WalletListenerPlugin.kt \
        app/javascript/services/wallet_listener.js \
        app/javascript/controllers/wallet_capture_settings_controller.js \
        app/views/settings/preferences/show.html.erb \
        config/locales/es.yml config/locales/en.yml
git commit -m "feat: UI de Settings para activar/ver estado de captura Wallet + reintento de pendientes"
```

---

### Task 5: Verificación end-to-end en dispositivo real + checklist de cierre

**Files:** ninguno (tarea de verificación, sin código nuevo)

- [ ] **Step 1: Los 3 puntos "sin verificar todavía" de `docs/CAPACITOR.md`**

En un dispositivo Android real, con la app instalada desde Android Studio:
1. Modo avión, cerrar la app del todo, reabrir → confirmar que sirve la versión cacheada (Service Worker) en vez de pantalla de error.
2. Login dentro del WebView de Capacitor → cerrar y reabrir la app → confirmar que la sesión persiste.
3. Crear un movimiento offline, reconectar → confirmar que sincroniza sin duplicados.

- [ ] **Step 2: Caso nuevo de este plan — captura Wallet con la app cerrada**

Con el acceso a notificaciones ya concedido (Task 4): cerrar la app del todo (no solo background) → hacer un pago de prueba con Wallet (o simular la notificación) → confirmar en Logcat que `WalletNotificationListenerService` recibe el evento aunque la app esté cerrada → abrir la app → confirmar en Settings → Preferences que el contador de pendientes bajó a 0 (se sincronizó) o que la compra aparece en el listado de transacciones.

- [ ] **Step 3: Caso de tarjeta no reconocida**

Simular una notificación de Wallet con un texto de tarjeta que NO esté en `AccountMapping` → confirmar que el evento `walletCapture` llega a JS con `status: "unrecognized_card"` y que no se manda nada al webhook (evita registrar un gasto con `account_id` inventado).

- [ ] **Step 4: Confirmar retiro de las iniciativas dominadas (una vez todo lo anterior verificado, no antes)**

- TWA (`financespy` repo): dejar de generar APKs nuevos; el existente puede quedar instalado hasta que el usuario migre a esta app, sin urgencia de desinstalar activamente.
- RN app `financespy-app` (rama `feature/financespy-mobile-app`): no se borra el código todavía (queda como referencia histórica), pero no se sigue desarrollando ni distribuyendo.
- Código OAuth/Doorkeeper mobile en `financespy` (`app/views/doorkeeper/authorizations/new.html.erb`, `app/controllers/doorkeeper/authorizations_controller.rb`, headers no-store agregados en la sesión 2026-08-11/12): queda sin caller. Decisión explícita de NO borrarlo en este plan — es candidato a limpieza en un PR aparte, después de confirmar en producción que nada lo usa.

- [ ] **Step 5: Merge**

```bash
git checkout feature/android-offline-phase1
git merge --no-ff feature/android-unified-wallet-capture
git push origin feature/android-offline-phase1
```

No mergear a `main`/rama por defecto todavía — `feature/android-offline-phase1` sigue siendo la rama de integración de todo lo móvil hasta que el usuario decida promoverla (fuera de alcance de este plan).
