package py.com.cdco.financespy.wallet

import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin

@CapacitorPlugin(name = "WalletListener")
class WalletListenerPlugin : Plugin() {
    private lateinit var store: PendingCaptureStore

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

    override fun handleOnDestroy() {
        super.handleOnDestroy()
        // WalletCaptureHandler.onResult es un var de vida de proceso: si no
        // lo limpiamos acá, sigue apuntando a este plugin (y por lo tanto a
        // la Bridge/Activity/WebView) después de que la Activity se destruye,
        // filtrándola y arriesgando invocar notifyListeners contra una
        // WebView desmontada si llega una captura tardía desde un hilo de
        // background.
        WalletCaptureHandler.onResult = null
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
        // Delegado a WalletCaptureHandler para que el remove() del reintento
        // corra en el MISMO executor que el add() de capturas nuevas — así
        // las mutaciones de PendingCaptureStore quedan serializadas en un
        // solo hilo y no hay carrera de lectura-modificación-escritura entre
        // el executor del plugin y el del handler.
        WalletCaptureHandler.retryPending(context) { applied ->
            val ret = JSObject()
            ret.put("applied", applied)
            call.resolve(ret)
        }
    }
}
