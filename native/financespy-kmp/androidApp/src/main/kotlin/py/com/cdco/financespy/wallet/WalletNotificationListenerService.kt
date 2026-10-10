package py.com.cdco.financespy.wallet

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class WalletNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName !in BankNotificationExtractors.watchedPackages) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        // bigText carries the full expanded body on banks that truncate
        // android.text in the collapsed notification (seen with Banco
        // Continental's transfer confirmations) -- fall back to android.text
        // for notifications that only ever set the short form.
        val text = extras.getCharSequence("android.bigText")?.toString()
            ?: extras.getCharSequence("android.text")?.toString() ?: ""
        if (title.isEmpty() && text.isEmpty()) return

        // Se llama directo acá porque el OS puede bindear/arrancar este Service
        // con el proceso en frío. Service extiende ContextWrapper, así que applicationContext
        // siempre está disponible acá.
        WalletCaptureHandler.handle(applicationContext, sbn.packageName, title, text)
    }
}
