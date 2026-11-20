package py.com.cdco.financespy.utils

import org.junit.Test
import kotlin.test.assertTrue

private class ConnectTimeoutException(message: String? = null) : Exception(message)
private class UnknownHostException(message: String? = null) : Exception(message)

class NetworkErrorsTest {
    @Test
    fun unauthorizedTellsTheSessionExpired() {
        val msg = RuntimeException("Client request(GET https://x/api) invalid: 401 Unauthorized. Text: \"{}\"").describeForUser()
        assertTrue(msg.contains("sesión expiró"), msg)
    }

    @Test
    fun tooManyRequestsAndServerErrors() {
        assertTrue(RuntimeException("Client request(GET u) invalid: 429 Too Many Requests.").describeForUser().contains("Demasiados intentos"))
        assertTrue(RuntimeException("Server error(GET u: 502 Bad Gateway. Text: x").describeForUser().contains("(502)"))
    }

    // Over HTTP/2 there is no reason phrase, so the real message from the
    // Cloudflare tunnel reads "502 ." -- this used to fall through to the raw text.
    @Test
    fun gatewayErrorWithoutReasonPhraseIsExplained() {
        val raw = "Server error(GET https://finance.cd-co.com.py/api/v1/family_settings: 502 . " +
            "Text: \"{\"title\":\"Error 502: Bad gateway\",\"status\":502,\"retry_after\":60}\""
        val msg = RuntimeException(raw).describeForUser()
        assertTrue(msg.contains("No se pudo llegar al servidor (502)"), msg)
        assertTrue(!msg.contains("cloudflare", ignoreCase = true), msg)
    }

    @Test
    fun timeoutsAndDnsAreExplainedAndNameTheException() {
        val timeout = ConnectTimeoutException("Connect timeout has expired").describeForUser()
        assertTrue(timeout.contains("Se agotó el tiempo"), timeout)
        assertTrue(timeout.contains("ConnectTimeoutException"), timeout)

        val dns = RuntimeException("wrapped", UnknownHostException()).describeForUser()
        assertTrue(dns.contains("No se encontró el servidor"), dns)
    }
}
