package py.com.cdco.financespy.wallet

import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class WalletNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName !in BankNotificationExtractors.watchedPackages) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val text = collectNotificationText(extras)
        if (title.isEmpty() && text.isEmpty()) return

        // Se llama directo acá porque el OS puede bindear/arrancar este Service
        // con el proceso en frío. Service extiende ContextWrapper, así que applicationContext
        // siempre está disponible acá.
        WalletCaptureHandler.handle(applicationContext, sbn.packageName, title, text)
    }

    // A notification's full content isn't always in a single field. Grouped
    // SMS conversations (MessagingStyle/InboxStyle, used by the default
    // Messages app) carry individual messages in "android.messages" or
    // "android.textLines" instead of -- or in addition to -- a single
    // "android.bigText"/"android.text". Collecting every source into one
    // blob (deduped) and running extractors with findAll over all of it is
    // what makes bundled multi-transaction notifications (see
    // ContinentalSmsExtractor) actually find every transaction instead of
    // only whichever field happened to be checked first.
    private fun collectNotificationText(extras: Bundle): String {
        val parts = LinkedHashSet<String>()

        extras.getCharSequence("android.bigText")?.toString()?.let { parts.add(it) }
        extras.getCharSequence("android.text")?.toString()?.let { parts.add(it) }

        extras.getCharSequenceArray("android.textLines")?.forEach { line ->
            line?.toString()?.let { parts.add(it) }
        }

        @Suppress("DEPRECATION")
        extras.getParcelableArray("android.messages")?.forEach { parcelable ->
            (parcelable as? Bundle)?.getCharSequence("text")?.toString()?.let { parts.add(it) }
        }

        return parts.joinToString("\n")
    }
}
