package py.com.cdco.financespy.wallet

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

sealed class WebhookResult {
    data class Success(val duplicate: Boolean) : WebhookResult()
    data class Failure(val error: String, val unauthorized: Boolean = false) : WebhookResult()
}

class WebhookClient(private val token: String) {
    companion object {
        private const val BASE_URL = "https://finance.cd-co.com.py"
        private const val OAUTH_CLIENT_ID = "Ti8y1yGMsJVyNv35wsWE2taV7NR4B3zdKduf7E5IZEM"

        /**
         * Exchanges a Doorkeeper refresh_token for a fresh (access_token, refresh_token) pair.
         * Returns null on any HTTP or network failure (never clears tokens here — if the refresh
         * token was concurrently rotated by ApiClient, the next retry will pick up the new one).
         */
        fun refreshAccessToken(refreshToken: String): Pair<String, String>? {
            var conn: HttpURLConnection? = null
            return try {
                val connection = URL("$BASE_URL/oauth/token").openConnection() as HttpURLConnection
                conn = connection
                connection.requestMethod = "POST"
                connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                connection.doOutput = true
                connection.connectTimeout = 10_000
                connection.readTimeout = 10_000

                val formBody = listOf(
                    "grant_type" to "refresh_token",
                    "client_id" to OAUTH_CLIENT_ID,
                    "refresh_token" to refreshToken
                ).joinToString("&") { (k, v) ->
                    "${URLEncoder.encode(k, "UTF-8")}=${URLEncoder.encode(v, "UTF-8")}"
                }
                connection.outputStream.use { it.write(formBody.toByteArray(Charsets.UTF_8)) }

                if (connection.responseCode == 200) {
                    val resp = JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
                    val newAccess = resp.optString("access_token")
                    val newRefresh = resp.optString("refresh_token")
                    if (newAccess.isNotBlank() && newRefresh.isNotBlank()) newAccess to newRefresh else null
                } else {
                    null
                }
            } catch (_: Exception) {
                null
            } finally {
                conn?.disconnect()
            }
        }
    }

    private val url = "$BASE_URL/api/v1/android_purchases"

    // rawText is passed in separately (never part of PendingCapture) because
    // it's only available for the very first attempt, straight from the
    // notification -- retries read a PendingCapture back from disk, where
    // it was never stored. See PendingCaptureStore for why.
    fun post(capture: PendingCapture, rawText: String? = null): WebhookResult {
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
                put("nature", capture.nature.name.lowercase())
                if (rawText != null) put("raw_text", rawText)
                put("timestamp", capture.capturedAt)
                if (capture.latitude != null && capture.longitude != null) {
                    put("latitude", capture.latitude)
                    put("longitude", capture.longitude)
                }
                if (capture.device != null) put("device", capture.device)
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
                    error = if (detail.isNullOrBlank()) "Unexpected status $status" else "Unexpected status $status: $detail",
                    unauthorized = status == 401
                )
            }
        } catch (e: Exception) {
            WebhookResult.Failure(e.message ?: "Unknown network error")
        } finally {
            conn?.disconnect()
        }
    }
}
