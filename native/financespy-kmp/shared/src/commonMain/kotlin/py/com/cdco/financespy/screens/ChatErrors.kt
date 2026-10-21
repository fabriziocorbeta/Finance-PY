package py.com.cdco.financespy.screens

import io.ktor.client.plugins.HttpRequestTimeoutException
import io.ktor.client.plugins.ResponseException
import io.ktor.client.statement.bodyAsText
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.jsonPrimitive

/** Spanish, user-facing texts for everything that can go wrong in the AI chat. */
internal object ChatErrors {
    const val FEATURE_DISABLED =
        "El asistente IA no está activado para tu cuenta. Activalo desde Ajustes en la versión web."
    const val BUSY = "El asistente está ocupado. Probá de nuevo en unos minutos."
    const val OFFLINE = "No se pudo conectar con el servidor. Revisá tu conexión a internet y probá de nuevo."
    const val SESSION_EXPIRED = "Tu sesión expiró. Cerrá sesión y volvé a entrar."
    const val FORBIDDEN = "No tenés permiso para usar el asistente."
    const val SERVER = "El servidor tuvo un problema. Probá de nuevo en un momento."
    const val ASSISTANT_FAILED = "El asistente no pudo responder. Probá de nuevo."

    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    /**
     * Turns the chat's `error` field into a message for the user, or null when there is none.
     * The API sends the already-friendly `presentable_error_message`, but older servers stored
     * the raw JSON payload ({"message": ..., "technical_message": ...}); never show that JSON.
     */
    fun fromChatError(raw: String?): String? {
        val text = raw?.trim()
        if (text.isNullOrEmpty()) return null
        if (!text.startsWith("{") && !text.startsWith("\"")) return text

        val element = try {
            json.parseToJsonElement(text)
        } catch (e: Exception) {
            return ASSISTANT_FAILED
        }
        return when (element) {
            is JsonObject -> (element["message"] as? JsonPrimitive)?.contentOrNull?.takeIf { it.isNotBlank() }
                ?: ASSISTANT_FAILED
            is JsonPrimitive -> element.contentOrNull?.let { fromChatError(it) } ?: ASSISTANT_FAILED
            else -> ASSISTANT_FAILED
        }
    }

    /** Maps a failed chat API call to a user message; [fallback] covers anything unrecognised. */
    suspend fun fromException(e: Throwable, fallback: String): String {
        if (e is ResponseException) {
            return when (val status = e.response.status.value) {
                401 -> SESSION_EXPIRED
                403 -> if (errorCode(e) == "feature_disabled") FEATURE_DISABLED else FORBIDDEN
                429, 503 -> BUSY
                else -> if (status >= 500) SERVER else fallback
            }
        }
        if (e is HttpRequestTimeoutException || e is kotlinx.io.IOException) return OFFLINE
        return fallback
    }

    private suspend fun errorCode(e: ResponseException): String? = try {
        val body = json.parseToJsonElement(e.response.bodyAsText())
        (body as? JsonObject)?.get("error")?.jsonPrimitive?.contentOrNull
    } catch (_: Exception) {
        // Body already consumed or not JSON: Ktor's default validator copies it into the message.
        if (e.message?.contains("feature_disabled") == true) "feature_disabled" else null
    }
}
