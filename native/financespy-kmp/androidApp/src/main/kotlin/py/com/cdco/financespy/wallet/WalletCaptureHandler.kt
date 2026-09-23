package py.com.cdco.financespy.wallet

import android.content.Context
import kotlinx.coroutines.runBlocking
import py.com.cdco.financespy.auth.AndroidTokenStorage
import java.time.Instant
import java.util.UUID
import java.util.concurrent.Executors

// Orquesta la captura completa (extraer -> mapear cuenta -> POST al webhook ->
// encolar si falla) usando solo un Context de Android.
// Necesario porque NotificationListenerService puede ser iniciado por el OS
// con el proceso en frío.
object WalletCaptureHandler {
    private val executor = Executors.newSingleThreadExecutor()

    // Optional native listener callback if UI or logger wants to observe capture events.
    var onResult: ((status: String, details: String) -> Unit)? = null

    fun handle(context: Context, title: String, text: String) {
        executor.execute {
            handleBlocking(context, title, text)
        }
    }

    private fun handleBlocking(context: Context, title: String, text: String) {
        val purchase = PurchaseExtractor.extract(text) ?: return
        val accountId = AccountMapping.accountIdFor(purchase.cardText)
        val capturedAt = Instant.now().toString()

        if (accountId == null) {
            onResult?.invoke("unrecognized_card", purchase.cardText)
            return
        }

        val capture = PendingCapture(
            id = UUID.randomUUID().toString(),
            capturedAt = capturedAt,
            accountId = accountId,
            amount = purchase.amount,
            merchant = title,
            item = purchase.cardText
        )

        val store = PendingCaptureStore(context)
        val token = runBlocking { AndroidTokenStorage(context).accessToken() }
        if (token.isNullOrBlank()) {
            store.add(capture)
            onResult?.invoke("token_missing", purchase.cardText)
            return
        }
        val result = WebhookClient(token).post(capture, rawText = text)

        when (result) {
            is WebhookResult.Success -> {
                onResult?.invoke(if (result.duplicate) "duplicate" else "created", purchase.cardText)
            }
            is WebhookResult.Failure -> {
                store.add(capture)
                onResult?.invoke("queued", result.error)
            }
        }
    }

    // Reintenta las capturas encoladas. Corre en el mismo executor que add()
    // para que las mutaciones de PendingCaptureStore queden serializadas.
    fun retryPending(context: Context, callback: ((applied: Int) -> Unit)? = null) {
        executor.execute {
            val store = PendingCaptureStore(context)
            val token = runBlocking { AndroidTokenStorage(context).accessToken() }
            if (token.isNullOrBlank()) {
                callback?.invoke(0)
                return@execute
            }
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

            callback?.invoke(applied)
        }
    }
}
