package py.com.cdco.financespy.wallet

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log

class WalletNotificationListenerService : NotificationListenerService() {
    companion object {
        const val WALLET_PACKAGE = "com.google.android.apps.walletnfcrel"
        private const val TAG = "WalletDebug"
    }

    // Heartbeat: el OS puede desconectar este listener (reboot, batería,
    // revocación de permiso) sin que quede ningún otro rastro -- confirmado
    // en producción: 3 compras reales de un mismo día (2026-08-15) se
    // perdieron sin llegar siquiera a la cola local, y no había forma de
    // saber si el listener estuvo vivo ese día. onListenerConnected/
    // Disconnected quedan en logcat (tag WalletDebug) para poder confirmar
    // con adb la próxima vez que pase.
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.i(TAG, "listener_connected")
    }

    override fun onListenerDisconnected() {
        super.onListenerDisconnected()
        Log.w(TAG, "listener_disconnected")
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName != WALLET_PACKAGE) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        Log.i(TAG, "notification_received title=\"$title\" text=\"$text\"")
        if (title.isEmpty() && text.isEmpty()) return

        // Se llama directo acá (no via un callback que dependa del plugin de
        // Capacitor) porque el OS puede bindear/arrancar este Service con el
        // proceso en frío, sin que la Activity de Capacitor ni
        // WalletListenerPlugin.load() lleguen a correr nunca. Service extiende
        // ContextWrapper, así que applicationContext siempre está disponible acá.
        WalletCaptureHandler.handle(applicationContext, title, text)
    }
}
