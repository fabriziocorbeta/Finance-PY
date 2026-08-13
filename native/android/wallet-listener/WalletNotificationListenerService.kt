package py.com.cdco.financespy.wallet

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class WalletNotificationListenerService : NotificationListenerService() {
    companion object {
        const val WALLET_PACKAGE = "com.google.android.apps.walletnfcrel"
    }

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName != WALLET_PACKAGE) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = extras.getCharSequence("android.text")?.toString() ?: ""
        if (title.isEmpty() && text.isEmpty()) return

        // Se llama directo acá (no via un callback que dependa del plugin de
        // Capacitor) porque el OS puede bindear/arrancar este Service con el
        // proceso en frío, sin que la Activity de Capacitor ni
        // WalletListenerPlugin.load() lleguen a correr nunca. Service extiende
        // ContextWrapper, así que applicationContext siempre está disponible acá.
        WalletCaptureHandler.handle(applicationContext, title, text)
    }
}
