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
data class PendingCapture(
    val id: String,
    val capturedAt: String,
    val accountId: String,
    val amount: String,
    val merchant: String,
    val item: String
)

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
                val obj = arr.getJSONObject(i)
                result.add(
                    PendingCapture(
                        id = obj.getString("id"),
                        capturedAt = obj.getString("capturedAt"),
                        accountId = obj.getString("accountId"),
                        amount = obj.getString("amount"),
                        merchant = obj.getString("merchant"),
                        item = obj.getString("item")
                    )
                )
            }
            result
        } catch (e: Exception) {
            emptyList()
        }
    }

    private fun writeAll(captures: List<PendingCapture>) {
        val arr = JSONArray()
        captures.forEach { c ->
            arr.put(JSONObject().apply {
                put("id", c.id)
                put("capturedAt", c.capturedAt)
                put("accountId", c.accountId)
                put("amount", c.amount)
                put("merchant", c.merchant)
                put("item", c.item)
            })
        }
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
