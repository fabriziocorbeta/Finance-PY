package py.com.cdco.financespy.network

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.get
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import io.ktor.client.plugins.auth.Auth
import io.ktor.client.plugins.auth.providers.bearer
import io.ktor.client.plugins.auth.providers.BearerTokens
import py.com.cdco.financespy.auth.TokenStorage
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import io.ktor.client.request.forms.submitForm
import py.com.cdco.financespy.auth.TokenResponse
import io.ktor.client.call.body
import io.ktor.http.Parameters
import io.ktor.client.plugins.ClientRequestException

class ApiClientAuthTest {

    class FakeTokenStorage : TokenStorage {
        var access: String? = "expired_token"
        var refresh: String? = "valid_refresh_token"

        override suspend fun save(accessToken: String, refreshToken: String) {
            access = accessToken
            refresh = refreshToken
        }

        override suspend fun accessToken(): String? = access
        override suspend fun refreshToken(): String? = refresh

        override suspend fun clear() {
            access = null
            refresh = null
        }
    }

    @Test
    fun testUnauthorizedTriggersRefreshAndRetriesRequest() = runTest {
        val tokenStorage = FakeTokenStorage()
        var requestCount = 0
        var tokenRequestCount = 0

        val mockEngine = MockEngine { request ->
            when (request.url.encodedPath) {
                "/test" -> {
                    requestCount++
                    if (request.headers["Authorization"] == "Bearer expired_token") {
                        respond("Unauthorized", HttpStatusCode.Unauthorized, headersOf("WWW-Authenticate", "Bearer"))
                    } else if (request.headers["Authorization"] == "Bearer new_access_token") {
                        respond("Success", HttpStatusCode.OK)
                    } else {
                        respond("Bad Auth", HttpStatusCode.BadRequest)
                    }
                }
                "/oauth/token" -> {
                    tokenRequestCount++
                    respond(
                        """{"access_token":"new_access_token","refresh_token":"new_refresh_token","token_type":"Bearer","expires_in":3600}""",
                        HttpStatusCode.OK,
                        headersOf("Content-Type", "application/json")
                    )
                }
                else -> respond("Not Found", HttpStatusCode.NotFound)
            }
        }

        val client = HttpClient(mockEngine) {
            install(Auth) {
                bearer {
                    sendWithoutRequest { true }
                    loadTokens {
                        val accessToken = tokenStorage.accessToken()
                        val refreshToken = tokenStorage.refreshToken()
                        if (accessToken != null && refreshToken != null) {
                            BearerTokens(accessToken, refreshToken)
                        } else null
                    }
                    refreshTokens {
                        val refreshToken = tokenStorage.refreshToken() ?: return@refreshTokens null

                        val refreshClient = HttpClient(mockEngine) {
                            install(ContentNegotiation) {
                                json(Json { ignoreUnknownKeys = true; isLenient = true })
                            }
                        }

                        try {
                            val response: TokenResponse = refreshClient.submitForm(
                                url = "https://finance.cd-co.com.py/oauth/token",
                                formParameters = Parameters.build {
                                    append("grant_type", "refresh_token")
                                    append("client_id", "test_client_id")
                                    append("refresh_token", refreshToken)
                                }
                            ).body()
                            tokenStorage.save(response.access_token, response.refresh_token)
                            BearerTokens(response.access_token, response.refresh_token)
                        } catch (e: ClientRequestException) {
                            tokenStorage.clear()
                            null
                        } catch (e: Exception) {
                            null
                        } finally {
                            refreshClient.close()
                        }
                    }
                }
            }
        }

        val response = client.get("https://finance.cd-co.com.py/test")

        assertEquals(HttpStatusCode.OK, response.status)
        assertEquals(2, requestCount)
        assertEquals(1, tokenRequestCount)
        assertEquals("new_access_token", tokenStorage.access)
    }
}
