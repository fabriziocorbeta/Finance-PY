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
    private val prefs = context.getSharedPreferences("wallet_listener_pending", Context.MODE_PRIVATE)
    private val KEY = "captures"

    fun add(capture: PendingCapture) {
        val all = readAll().toMutableList()
        all.add(capture)
        writeAll(all)
    }

    fun readAll(): List<PendingCapture> {
        val raw = prefs.getString(KEY, null) ?: return emptyList()
        val arr = JSONArray(raw)
        return (0 until arr.length()).map { i ->
            val o = arr.getJSONObject(i)
            PendingCapture(
                id = o.getString("id"),
                capturedAt = o.getString("capturedAt"),
                rawText = o.getString("rawText"),
                accountId = o.getString("accountId"),
                amount = o.getString("amount"),
                merchant = o.getString("merchant"),
                item = o.getString("item")
            )
        }
    }

    fun remove(id: String) {
        writeAll(readAll().filterNot { it.id == id })
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
