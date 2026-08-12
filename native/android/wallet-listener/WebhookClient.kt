package py.com.cdco.financespy.wallet

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

sealed class WebhookResult {
    data class Success(val duplicate: Boolean) : WebhookResult()
    data class Failure(val error: String) : WebhookResult()
}

class WebhookClient(private val token: String) {
    private val url = "https://finance.cd-co.com.py/webhooks/android_purchase"

    fun post(capture: PendingCapture): WebhookResult {
        return try {
            val conn = URL(url).openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Authorization", "Bearer $token")
            conn.setRequestProperty("Content-Type", "application/json")
            conn.doOutput = true
            conn.connectTimeout = 10_000
            conn.readTimeout = 10_000

            val body = JSONObject().apply {
                put("account_id", capture.accountId)
                put("amount", capture.amount)
                put("merchant", capture.merchant)
                put("item", capture.item)
                put("raw_text", capture.rawText)
                put("timestamp", capture.capturedAt)
            }
            conn.outputStream.use { it.write(body.toString().toByteArray()) }

            val status = conn.responseCode
            if (status == 200 || status == 201) {
                val respBody = conn.inputStream.bufferedReader().use { it.readText() }
                val duplicate = JSONObject(respBody).optBoolean("duplicate", false)
                WebhookResult.Success(duplicate)
            } else {
                WebhookResult.Failure("Unexpected status $status")
            }
        } catch (e: Exception) {
            WebhookResult.Failure(e.message ?: "Unknown network error")
        }
    }
}
