package py.com.cdco.financespy.wallet

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import py.com.cdco.financespy.security.EncryptedPrefsFactory
import java.security.MessageDigest

// Bank/payment apps commonly re-post (update) an existing notification as new
// messages arrive in the same thread -- and WalletNotificationListenerService's
// notification-part collection reads the notification's full visible history
// (android.textLines / android.messages), not just what changed since the
// last post. So every onNotificationPosted call for the SAME conversation
// re-includes parts already handed to the extractors in a previous call.
//
// Confirmed live against real duplicate rows (2026-10-29..31, Familia
// Corbeta): the same purchase (e.g. "OVEJA NEGRA SRL LUQUE", Gs. 65.000) got
// captured 2-4 times, with re-captures landing anywhere from ~1 second to
// ~4 hours after the first. The backend's idempotency check (external_id,
// see AndroidPurchase::WebhookProcessor) didn't catch it because its hash
// includes the client's processing-time timestamp (Instant.now() at capture
// time), which is different on every re-capture -- that check is correct for
// retrying the SAME queued capture (PendingCaptureStore reuses the original
// capturedAt), just not for a brand new extraction of a message already seen.
//
// This filters at the true source instead: each notification part (one
// bigText/text blob, or one line from a grouped SMS/messaging notification)
// is hashed and checked against a short-lived, persisted set of recently
// seen hashes. Only genuinely new parts reach the extractors, so an
// already-captured transaction never gets re-extracted just because the
// notification it came from was reposted with more history attached.
//
// Split into pure, Context-free functions (filterNewParts, hashOfNotificationPart,
// (de)serialization) plus a thin persistence wrapper, mirroring
// PendingCaptureStore/parseCaptureJson/captureToJson in this same package --
// keeps the actual dedup logic unit-testable without a real or Robolectric
// Context/EncryptedSharedPreferences.

internal data class SeenPartEntry(val hash: String, val seenAtMillis: Long)

internal fun hashOfNotificationPart(value: String): String {
    val digest = MessageDigest.getInstance("SHA-256").digest(value.toByteArray(Charsets.UTF_8))
    return digest.joinToString("") { "%02x".format(it) }
}

internal fun parseSeenEntriesJson(json: String): List<SeenPartEntry> = try {
    val arr = JSONArray(json)
    (0 until arr.length()).map { i ->
        val obj = arr.getJSONObject(i)
        SeenPartEntry(obj.getString("hash"), obj.getLong("seenAt"))
    }
} catch (e: Exception) {
    emptyList()
}

internal fun seenEntriesToJson(entries: List<SeenPartEntry>): String {
    val arr = JSONArray()
    entries.forEach { entry ->
        arr.put(
            JSONObject().apply {
                put("hash", entry.hash)
                put("seenAt", entry.seenAtMillis)
            }
        )
    }
    return arr.toString()
}

// Pure core of the dedup: given what's currently stored, the parts just
// observed, "now", and the retention window/cap, returns the parts that are
// genuinely new plus the entry list to persist afterward. No Android
// dependency, so this is exercised directly in SeenNotificationPartsStoreTest.
//
// Entries older than ttlMillis are dropped before matching (not just before
// writing) so a part identical to one seen outside the window -- e.g. a
// real second purchase of the same amount at the same merchant the next day
// -- is treated as new, not silently swallowed as a "duplicate".
internal fun filterNewParts(
    storedEntries: List<SeenPartEntry>,
    parts: List<String>,
    now: Long,
    ttlMillis: Long,
    maxEntries: Int
): Pair<List<String>, List<SeenPartEntry>> {
    val live = storedEntries.filter { now - it.seenAtMillis <= ttlMillis }.toMutableList()
    val seenHashes = live.mapTo(HashSet()) { it.hash }
    val newParts = mutableListOf<String>()

    parts.forEach { part ->
        val hash = hashOfNotificationPart(part)
        if (seenHashes.add(hash)) {
            live.add(SeenPartEntry(hash, now))
            newParts.add(part)
        }
    }

    val trimmed = if (live.size > maxEntries) live.takeLast(maxEntries) else live
    return newParts to trimmed
}

class SeenNotificationPartsStore(
    context: Context,
    private val ttlMillis: Long = DEFAULT_TTL_MILLIS,
    private val maxEntries: Int = DEFAULT_MAX_ENTRIES,
    private val clock: () -> Long = { System.currentTimeMillis() }
) {
    companion object {
        private const val PREFS_NAME = "wallet_seen_notification_parts"
        private const val KEY_ENTRIES = "seen_entries"
        const val DEFAULT_MAX_ENTRIES = 500

        // Observed re-captures of the same real notification landed anywhere
        // from ~1 second to ~4 hours after the first (see class doc above).
        // 6h gives headroom above that without treating a genuinely new,
        // identical-looking purchase a day later as a duplicate.
        const val DEFAULT_TTL_MILLIS = 6 * 60 * 60 * 1000L
    }

    private val prefs = EncryptedPrefsFactory.create(context.applicationContext, PREFS_NAME)

    @Synchronized
    fun filterNew(parts: List<String>): List<String> {
        if (parts.isEmpty()) return parts

        val stored = parseSeenEntriesJson(prefs.getString(KEY_ENTRIES, "[]") ?: "[]")
        val (newParts, updated) = filterNewParts(stored, parts, clock(), ttlMillis, maxEntries)

        if (newParts.isNotEmpty()) {
            prefs.edit().putString(KEY_ENTRIES, seenEntriesToJson(updated)).apply()
        }

        return newParts
    }
}
