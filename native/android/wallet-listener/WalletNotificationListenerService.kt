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
