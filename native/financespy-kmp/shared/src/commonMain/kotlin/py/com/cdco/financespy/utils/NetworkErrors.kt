package py.com.cdco.financespy.utils

import io.ktor.client.plugins.ResponseException

// A 3-digit status right after a colon. The reason phrase is optional: over
// HTTP/2 (Cloudflare) there is none, so Ktor's message reads "...: 502 . Text:"
// and the previous pattern, which required a capitalised phrase after the
// number, missed it and the raw exception text ended up on screen.
private val statusRegex = Regex(""":\s*(\d{3})(?!\d)""")

/**
 * Turns a network/HTTP failure into a message a person can act on, plus the
 * technical exception name in parentheses so a screenshot is enough to diagnose.
 */
fun Throwable.describeForUser(): String {
    val chain = generateSequence(this) { it.cause }.take(6).toList()
    val names = chain.map { it::class.simpleName.orEmpty() }
    val text = chain.mapNotNull { it.message }.joinToString(" ")
    val status = chain.firstNotNullOfOrNull { (it as? ResponseException)?.response?.status?.value }
        ?: statusRegex.find(text)?.groupValues?.get(1)?.toIntOrNull()
    val nameBlob = names.joinToString(" ")

    val human = when {
        status == 401 -> "Tu sesión expiró o no es válida. Cerrá sesión y volvé a entrar."
        status == 403 -> "No tenés permiso para esto."
        status == 404 -> "No se encontró lo pedido en el servidor."
        status == 409 -> "Conflicto con el estado actual del registro. Actualizá e intentá de nuevo."
        status == 422 -> "Revisá los datos ingresados: el servidor rechazó la validación."
        status == 429 -> "Demasiados intentos seguidos. Esperá un momento y reintentá."
        status in setOf(502, 503, 504) ->
            "No se pudo llegar al servidor ($status). Suele durar unos segundos: reintentá."
        status != null && status >= 500 -> "El servidor tuvo un problema ($status). Reintentá en un momento."
        nameBlob.contains("Timeout", ignoreCase = true) ->
            "Se agotó el tiempo esperando al servidor. La conexión está lenta o inestable."
        nameBlob.contains("UnknownHost") || nameBlob.contains("UnresolvedAddress") ->
            "No se encontró el servidor. Revisá tu conexión o el DNS."
        nameBlob.contains("ConnectException") || nameBlob.contains("NoRouteToHost") ||
            nameBlob.contains("SocketException") -> "No se pudo conectar con el servidor."
        nameBlob.contains("SSL") || nameBlob.contains("Certificate") -> "Error de seguridad (TLS) al conectar."
        nameBlob.contains("Serialization") || nameBlob.contains("JsonConvert") ||
            nameBlob.contains("NoTransformation") -> "El servidor respondió algo inesperado."
        else -> message ?: "Error desconocido"
    }
    return "$human (${names.firstOrNull() ?: "Error"})"
}
