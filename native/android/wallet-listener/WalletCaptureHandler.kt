package py.com.cdco.financespy.wallet

import android.content.Context
import com.getcapacitor.JSObject
import java.time.Instant
import java.util.UUID
import java.util.concurrent.Executors

// Orquesta la captura completa (extraer -> mapear cuenta -> POST al webhook ->
// encolar si falla) usando solo un Context de Android, sin depender del
// plugin/Activity de Capacitor. Necesario porque NotificationListenerService
// puede ser iniciado por el OS con el proceso en frío, sin que la Activity de
// Capacitor ni WalletListenerPlugin.load() lleguen a correr nunca — ver
// WalletNotificationListenerService, que llama acá directamente con
// applicationContext.
object WalletCaptureHandler {
    private val executor = Executors.newSingleThreadExecutor()

    // Google Wallet postea la notificación y después la actualiza con el mismo
    // contenido (mismo título+texto) poco despues -- onNotificationPosted se
    // dispara de nuevo para esa actualizacion, y sin este chequeo cada disparo
    // generaba una compra nueva (confirmado en produccion: 2 Entries reales
    // idénticas, creadas con 2 segundos de diferencia). Dedup por contenido
    // exacto en una ventana corta -- corre serializado en el mismo executor
    // que el resto, no necesita lock aparte.
    private val recentCaptures = mutableMapOf<String, Long>()
    private const val DEDUP_WINDOW_MS = 60_000L

    private fun isDuplicateNotification(title: String, text: String): Boolean {
        val key = "$title|$text"
        val now = System.currentTimeMillis()
        recentCaptures.entries.removeAll { now - it.value > DEDUP_WINDOW_MS }
        val lastSeen = recentCaptures[key]
        recentCaptures[key] = now
        return lastSeen != null
    }

    // Enganchado por WalletListenerPlugin.load() cuando el plugin/Activity
    // están vivos, para que la UI reciba el evento "walletCapture". La
    // captura/POST/cola funcionan igual aunque nadie se suscriba acá.
    var onResult: ((JSObject) -> Unit)? = null

    fun handle(context: Context, title: String, text: String) {
        executor.execute {
            handleBlocking(context, title, text)
        }
    }

    private fun handleBlocking(context: Context, title: String, text: String) {
        if (isDuplicateNotification(title, text)) return
        val purchase = PurchaseExtractor.extract(text) ?: return
        val accountId = AccountMapping.accountIdFor(purchase.cardText)
        val capturedAt = Instant.now().toString()

        val data = JSObject()
        data.put("merchant", title)
        data.put("amount", purchase.amount)
        data.put("cardText", purchase.cardText)

        if (accountId == null) {
            data.put("status", "unrecognized_card")
            onResult?.invoke(data)
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

        val store = PendingCaptureStore(context)
        val tokenResId = context.resources.getIdentifier("wallet_webhook_token", "string", context.packageName)
        if (tokenResId == 0) {
            store.add(capture)
            data.put("status", "token_missing")
            onResult?.invoke(data)
            return
        }
        val token = context.getString(tokenResId)
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
        onResult?.invoke(data)
    }

    // Reintenta las capturas encoladas. Corre en el mismo executor que add()
    // (arriba) para que las mutaciones de PendingCaptureStore (add/remove)
    // queden serializadas en un solo hilo — antes del refactor esto ya
    // corría en el único executor del plugin; ahora que el plugin tiene su
    // propio executor para otras cosas, el store solo es seguro si todos
    // los remove()/add() pasan por acá.
    fun retryPending(context: Context, callback: (applied: Int) -> Unit) {
        executor.execute {
            val store = PendingCaptureStore(context)
            val tokenResId = context.resources.getIdentifier("wallet_webhook_token", "string", context.packageName)
            if (tokenResId == 0) {
                callback(0)
                return@execute
            }
            val token = context.getString(tokenResId)
            val client = WebhookClient(token)
            var applied = 0

            store.readAll().forEach { capture ->
                when (client.post(capture)) {
                    is WebhookResult.Success -> {
                        store.remove(capture.id)
                        applied++
                    }
                    is WebhookResult.Failure -> {
                        // se queda en la cola, se reintenta en la próxima llamada
                    }
                }
            }

            callback(applied)
        }
    }
}
