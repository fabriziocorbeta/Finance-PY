package py.com.cdco.financespy.wallet

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

data class PendingCapture(
    val id: String,
    val capturedAt: String,
    val rawText: String,
    val accountId: String,
    val amount: String,
    val merchant: String,
    val item: String
)

class PendingCaptureStore(context: Context) {
    companion object {
        private const val PREFS_NAME = "wallet_pending_captures"
        private const val KEY = "pending_list"
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun add(capture: PendingCapture) {
        val current = readAll().toMutableList()
        current.add(capture)
        writeAll(current)
    }

    fun remove(id: String) {
        val current = readAll().filterNot { it.id == id }
        writeAll(current)
    }

    fun readAll(): List<PendingCapture> {
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
                        rawText = obj.getString("rawText"),
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
                put("rawText", c.rawText)
                put("accountId", c.accountId)
                put("amount", c.amount)
                put("merchant", c.merchant)
                put("item", c.item)
            })
        }
        prefs.edit().putString(KEY, arr.toString()).apply()
    }
}
