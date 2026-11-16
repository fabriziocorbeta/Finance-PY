package py.com.cdco.financespy.network

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.plugins.ServerResponseException
import io.ktor.client.request.get
import io.ktor.client.request.post
import io.ktor.client.statement.bodyAsText
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class TransientGatewayRetryTest {
    private fun clientReturning(statuses: List<HttpStatusCode>, calls: MutableList<String>): HttpClient {
        val engine = MockEngine { request ->
            val status = statuses.getOrElse(calls.size) { statuses.last() }
            calls += request.method.value
            respond(content = if (status == HttpStatusCode.OK) "ok" else "bad gateway", status = status)
        }
        return HttpClient(engine) {
            expectSuccess = true
            installTransientGatewayRetry(delayForRetry = { 1L })
        }
    }

    @Test
    fun getIsRetriedUntilTheGatewayRecovers() = runTest {
        val calls = mutableListOf<String>()
        val client = clientReturning(
            listOf(HttpStatusCode.BadGateway, HttpStatusCode.ServiceUnavailable, HttpStatusCode.OK),
            calls
        )

        assertEquals("ok", client.get("https://example.test/api/v1/dashboard").bodyAsText())
        assertEquals(3, calls.size)
    }

    @Test
    fun getGivesUpAfterTheConfiguredRetries() = runTest {
        val calls = mutableListOf<String>()
        val client = clientReturning(listOf(HttpStatusCode.BadGateway), calls)

        assertFailsWith<ServerResponseException> { client.get("https://example.test/api/v1/dashboard") }
        // 1 original attempt + 4 retries
        assertEquals(5, calls.size)
    }

    // Repeating a write could create the same sale or transaction twice.
    @Test
    fun postIsNeverRetried() = runTest {
        val calls = mutableListOf<String>()
        val client = clientReturning(listOf(HttpStatusCode.BadGateway), calls)

        assertFailsWith<ServerResponseException> { client.post("https://example.test/api/v1/sales") }
        assertEquals(1, calls.size)
    }

    @Test
    fun aRealServerErrorIsNotRetried() = runTest {
        val calls = mutableListOf<String>()
        val client = clientReturning(listOf(HttpStatusCode.InternalServerError), calls)

        assertFailsWith<ServerResponseException> { client.get("https://example.test/api/v1/dashboard") }
        assertEquals(1, calls.size)
    }
}
