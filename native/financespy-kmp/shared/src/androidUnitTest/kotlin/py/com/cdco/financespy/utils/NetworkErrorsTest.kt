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

    @Test
    fun timeoutsAndDnsAreExplainedAndNameTheException() {
        val timeout = ConnectTimeoutException("Connect timeout has expired").describeForUser()
        assertTrue(timeout.contains("Se agotó el tiempo"), timeout)
        assertTrue(timeout.contains("ConnectTimeoutException"), timeout)

        val dns = RuntimeException("wrapped", UnknownHostException()).describeForUser()
        assertTrue(dns.contains("No se encontró el servidor"), dns)
    }
}
