package py.com.cdco.financespy.wallet

import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

internal data class NotificationMessagePart(val text: String, val timeMillis: Long)

// Pure core of notification part extraction so it can be unit-tested without
// Android's Bundle/NotificationListenerService. When MessagingStyle provides
// individual messages with timestamps (`android.messages`), messages older
// than `maxAgeMillis` are dropped so an un-dismissed SMS from days ago is
// never re-extracted when a new SMS arrives in the same thread (after
// SeenNotificationPartsStore's 6h TTL has expired).
internal fun extractNotificationParts(
    bigText: String?,
    text: String?,
    textLines: List<String>,
    messages: List<NotificationMessagePart>,
    nowMillis: Long,
    maxAgeMillis: Long = SeenNotificationPartsStore.DEFAULT_TTL_MILLIS
): List<String> {
    if (messages.isNotEmpty()) {
        return messages
            .asSequence()
            .filter { it.timeMillis <= 0L || nowMillis - it.timeMillis <= maxAgeMillis }
            .map { it.text }
            .filter { it.isNotBlank() }
            .distinct()
            .toList()
    }

    val parts = LinkedHashSet<String>()
    bigText?.let { parts.add(it) }
    text?.let { parts.add(it) }
    textLines.forEach { parts.add(it) }
    return parts.toList()
}

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

    private fun collectNotificationParts(extras: Bundle): List<String> {
        val bigText = extras.getCharSequence("android.bigText")?.toString()
        val text = extras.getCharSequence("android.text")?.toString()
        val textLines = extras.getCharSequenceArray("android.textLines")
            ?.mapNotNull { it?.toString() }
            ?: emptyList()

        @Suppress("DEPRECATION")
        val messages = extras.getParcelableArray("android.messages")
            ?.mapNotNull { parcelable ->
                val bundle = parcelable as? Bundle ?: return@mapNotNull null
                val msgText = bundle.getCharSequence("text")?.toString() ?: return@mapNotNull null
                val msgTime = bundle.getLong("time", 0L)
                NotificationMessagePart(msgText, msgTime)
            }
            ?: emptyList()

        return extractNotificationParts(
            bigText = bigText,
            text = text,
            textLines = textLines,
            messages = messages,
            nowMillis = System.currentTimeMillis()
        )
    }
}
