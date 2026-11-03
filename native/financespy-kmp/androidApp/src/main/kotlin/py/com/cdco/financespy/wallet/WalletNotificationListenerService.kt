package py.com.cdco.financespy.wallet

import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

class WalletNotificationListenerService : NotificationListenerService() {
    override fun onNotificationPosted(sbn: StatusBarNotification) {
        if (sbn.packageName !in BankNotificationExtractors.watchedPackages) return

        val extras = sbn.notification.extras
        val title = extras.getCharSequence("android.title")?.toString() ?: ""
        val parts = collectNotificationParts(extras)
        if (title.isEmpty() && parts.isEmpty()) return

        // Bank/payment apps commonly re-post (update) an existing notification
        // with its full visible history re-attached as new messages arrive in
        // the same thread, so this callback re-receives parts already handed
        // to the extractors on a previous call. Filter those out here, before
        // anything reaches the extractors/backend -- see SeenNotificationPartsStore
        // for why the backend's own external_id idempotency check can't catch
        // this (confirmed live duplicate captures, Familia Corbeta Oct-Nov 2026).
        val newParts = SeenNotificationPartsStore(applicationContext).filterNew(parts)
        if (newParts.isEmpty()) return

        val text = newParts.joinToString("\n")

        // Se llama directo acá porque el OS puede bindear/arrancar este Service
        // con el proceso en frío. Service extiende ContextWrapper, así que applicationContext
        // siempre está disponible acá.
        WalletCaptureHandler.handle(applicationContext, sbn.packageName, title, text)
    }

    // A notification's full content isn't always in a single field. Grouped
    // SMS conversations (MessagingStyle/InboxStyle, used by the default
    // Messages app) carry individual messages in "android.messages" or
    // "android.textLines" instead of -- or in addition to -- a single
    // "android.bigText"/"android.text". Collecting every source into
    // individual parts (deduped) and running extractors with findAll over
    // all of them is what makes bundled multi-transaction notifications (see
    // ContinentalSmsExtractor) actually find every transaction instead of
    // only whichever field happened to be checked first. Kept as separate
    // parts (rather than pre-joined) so SeenNotificationPartsStore can filter
    // out individually already-seen lines from a repost that also carries
    // genuinely new ones.
    private fun collectNotificationParts(extras: Bundle): List<String> {
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

        return parts.toList()
    }
}
