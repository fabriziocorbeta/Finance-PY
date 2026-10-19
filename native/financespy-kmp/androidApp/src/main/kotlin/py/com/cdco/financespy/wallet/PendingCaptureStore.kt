package py.com.cdco.financespy.wallet

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import py.com.cdco.financespy.cache.OwnershipGuard
import py.com.cdco.financespy.security.EncryptedPrefsFactory
import py.com.cdco.financespy.security.OwnerScope

// rawText (the full Wallet notification text -- can carry a masked card
// number and other account-adjacent text) is deliberately NOT part of this
// model: it's only ever needed as an ephemeral value for the *first*
// webhook POST attempt (see WalletCaptureHandler), never persisted to disk.
// Everything the app actually needs to reconcile/retry a capture -- account,
// amount, merchant, item, timestamp -- is already broken out below.
// accountId is nullable on purpose: a capture whose card text matched no
// account used to be thrown away on the spot, which silently lost real
// money (confirmed live -- two Google Pay purchases vanished after the
// matching account was renamed). Those are now queued with a null accountId
// and re-resolved on every retryPending(), so the capture heals itself as
// soon as an account matches again.
data class PendingCapture(
    val id: String,
    val capturedAt: String,
    val accountId: String?,
    val amount: String,
    val merchant: String,
    val item: String,
    val nature: TransactionNature = TransactionNature.EXPENSE,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val device: String? = null
)

// Pure, Context-free (de)serialization for one PendingCapture -- split out
// from the class above so this can be unit tested directly (JSON format
// compatibility with items already queued on disk) without needing a real
// or Robolectric-shadowed EncryptedSharedPreferences/AndroidKeyStore.
internal fun parseCaptureJson(obj: JSONObject): PendingCapture = PendingCapture(
    id = obj.getString("id"),
    capturedAt = obj.getString("capturedAt"),
    // Absent (or JSON null) for an unmatched capture. Reading with has()/
    // isNull() rather than getString() keeps items queued by older builds,
    // which always wrote the key, parsing unchanged.
    accountId = if (obj.has("accountId") && !obj.isNull("accountId")) obj.getString("accountId") else null,
    amount = obj.getString("amount"),
    merchant = obj.getString("merchant"),
    item = obj.getString("item"),
    nature = if (obj.has("nature")) TransactionNature.valueOf(obj.getString("nature")) else TransactionNature.EXPENSE,
    latitude = if (obj.has("latitude")) obj.getDouble("latitude") else null,
    longitude = if (obj.has("longitude")) obj.getDouble("longitude") else null,
    device = if (obj.has("device")) obj.getString("device") else null
)

internal fun captureToJson(c: PendingCapture): JSONObject = JSONObject().apply {
    put("id", c.id)
    put("capturedAt", c.capturedAt)
    c.accountId?.let { put("accountId", it) }
    put("amount", c.amount)
    put("merchant", c.merchant)
    put("item", c.item)
    put("nature", c.nature.name)
    c.latitude?.let { put("latitude", it) }
    c.longitude?.let { put("longitude", it) }
    c.device?.let { put("device", it) }
}

class PendingCaptureStore(
    context: Context,
    private val ownerId: () -> String? = { OwnerScope.currentOwnerId(context.applicationContext) }
) {
    companion object {
        private const val PREFS_NAME = "wallet_pending_captures"
        private const val KEY = "pending_list"
        private const val OWNER_KEY = "_owner_family_id"
    }

    private val prefs = EncryptedPrefsFactory.create(context.applicationContext, PREFS_NAME)

    @Volatile private var lastCheckedOwner: String? = null

    fun add(capture: PendingCapture) {
        ensureOwnerScope()
        val current = readAllInternal().toMutableList()
        current.add(capture)
        writeAll(current)
    }

    fun remove(id: String) {
        ensureOwnerScope()
        val current = readAllInternal().filterNot { it.id == id }
        writeAll(current)
    }

    fun readAll(): List<PendingCapture> {
        ensureOwnerScope()
        return readAllInternal()
    }

    /** Drops every queued Wallet capture. */
    fun wipeAll() {
        prefs.edit().clear().apply()
        lastCheckedOwner = null
    }

    private fun readAllInternal(): List<PendingCapture> {
        val jsonString = prefs.getString(KEY, "[]") ?: "[]"
        return try {
            val arr = JSONArray(jsonString)
            val result = mutableListOf<PendingCapture>()
            for (i in 0 until arr.length()) {
                result.add(parseCaptureJson(arr.getJSONObject(i)))
            }
            result
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun writeAll(captures: List<PendingCapture>) {
        val arr = JSONArray()
        captures.forEach { arr.put(captureToJson(it)) }
        prefs.edit().putString(KEY, arr.toString()).apply()
    }

    private fun ensureOwnerScope() {
        val current = ownerId() ?: return
        if (current == lastCheckedOwner) return

        val stored = prefs.getString(OWNER_KEY, null)
        if (OwnershipGuard.shouldWipe(stored, current)) {
            prefs.edit().clear().putString(OWNER_KEY, current).apply()
        } else if (stored == null) {
            prefs.edit().putString(OWNER_KEY, current).apply()
        }
        lastCheckedOwner = current
    }
}
