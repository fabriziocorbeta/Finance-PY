package py.com.cdco.financespy.wallet

import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import java.util.concurrent.Executors

@CapacitorPlugin(name = "WalletListener")
class WalletListenerPlugin : Plugin() {
    private lateinit var store: PendingCaptureStore
    private val notificationExecutor = Executors.newSingleThreadExecutor()

    override fun load() {
        store = PendingCaptureStore(context)

        // La captura/extracción/mapeo/POST/cola viven en WalletCaptureHandler,
        // que solo necesita un Context y por eso funciona aunque el proceso
        // arranque en frío sin que este plugin llegue a cargar (ver
        // WalletNotificationListenerService). Acá solo nos enganchamos para
        // reflejar el resultado en la UI cuando el plugin sí está vivo.
        WalletCaptureHandler.onResult = { data ->
            notifyListeners("walletCapture", data)
        }
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

    @PluginMethod
    fun retryPending(call: PluginCall) {
        notificationExecutor.execute {
            val ret = JSObject()

            val tokenResId = context.resources.getIdentifier("wallet_webhook_token", "string", context.packageName)
            if (tokenResId == 0) {
                ret.put("applied", 0)
                call.resolve(ret)
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

            ret.put("applied", applied)
            call.resolve(ret)
        }
    }
}
