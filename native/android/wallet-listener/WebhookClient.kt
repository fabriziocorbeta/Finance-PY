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
        var conn: HttpURLConnection? = null
        return try {
            val connection = URL(url).openConnection() as HttpURLConnection
            conn = connection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Authorization", "Bearer $token")
            connection.setRequestProperty("Content-Type", "application/json")
            connection.doOutput = true
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000

            val body = JSONObject().apply {
                put("account_id", capture.accountId)
                // El monto llega de PurchaseExtractor con separador de miles
                // (ej. "150,000") porque así viene en el texto de la
                // notificación de Wallet. El backend Rails hace
                // BigDecimal(amount) y explota con una coma adentro, así que
                // se normaliza acá, justo antes de armar el body — esto
                // también sana los items que ya están en la cola local con
                // el monto sin normalizar cuando retryPending() los reenvía.
                put("amount", capture.amount.replace(",", ""))
                put("merchant", capture.merchant)
                put("item", capture.item)
                put("raw_text", capture.rawText)
                put("timestamp", capture.capturedAt)
            }
            connection.outputStream.use { it.write(body.toString().toByteArray()) }

            val status = connection.responseCode
            if (status == 200 || status == 201) {
                val respBody = connection.inputStream.bufferedReader().use { it.readText() }
                val duplicate = JSONObject(respBody).optBoolean("duplicate", false)
                WebhookResult.Success(duplicate)
            } else {
                val errorBody = connection.errorStream?.bufferedReader()?.use { it.readText() }
                val detail = errorBody?.takeIf { it.isNotBlank() }?.let { raw ->
                    try {
                        JSONObject(raw).optString("error", raw)
                    } catch (e: Exception) {
                        raw
                    }
                }
                WebhookResult.Failure(
                    if (detail.isNullOrBlank()) "Unexpected status $status" else "Unexpected status $status: $detail"
                )
            }
        } catch (e: Exception) {
            WebhookResult.Failure(e.message ?: "Unknown network error")
        } finally {
            conn?.disconnect()
        }
    }
}
