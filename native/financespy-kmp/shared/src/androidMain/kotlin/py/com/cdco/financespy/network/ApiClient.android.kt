package py.com.cdco.financespy.network

import io.ktor.client.HttpClient
import io.ktor.client.HttpClientConfig
import io.ktor.client.call.body
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.auth.Auth
import io.ktor.client.plugins.auth.providers.BearerTokens
import io.ktor.client.plugins.auth.providers.bearer
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.forms.submitForm
import io.ktor.http.Parameters
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import py.com.cdco.financespy.auth.TokenResponse
import py.com.cdco.financespy.auth.TokenStorage
import io.ktor.client.plugins.ClientRequestException

private const val CLIENT_ID = "Ti8y1yGMsJVyNv35wsWE2taV7NR4B3zdKduf7E5IZEM"

actual fun createPlatformClient(tokenStorage: TokenStorage, config: HttpClientConfig<*>.() -> Unit): HttpClient {
    return HttpClient(OkHttp) {
        config()
        install(Auth) {
            bearer {
                sendWithoutRequest { true }
                loadTokens {
                    val accessToken = tokenStorage.accessToken()
                    val refreshToken = tokenStorage.refreshToken()
                    if (accessToken != null && refreshToken != null) {
                        BearerTokens(accessToken, refreshToken)
                    } else {
                        null
                    }
                }
                refreshTokens {
                    val refreshToken = tokenStorage.refreshToken() ?: return@refreshTokens null

                    val refreshClient = HttpClient(OkHttp) {
                        install(ContentNegotiation) {
                            json(Json { ignoreUnknownKeys = true; isLenient = true })
                        }
                    }

                    try {
                        val response: TokenResponse = refreshClient.submitForm(
                            url = "${ApiClient.BASE_URL}/oauth/token",
                            formParameters = Parameters.build {
                                append("grant_type", "refresh_token")
                                append("client_id", CLIENT_ID)
                                append("refresh_token", refreshToken)
                            }
                        ).body()
                        tokenStorage.save(response.access_token, response.refresh_token)
                        BearerTokens(response.access_token, response.refresh_token)
                    } catch (e: ClientRequestException) {
                        // For example, 400 Bad Request or 401 Unauthorized during refresh
                        tokenStorage.clear()
                        null
                    } catch (e: Exception) {
                        // Network error or serialization error, don't logout, just return null
                        // so the request can be retried later or fails with network error.
                        null
                    } finally {
                        refreshClient.close()
                    }
                }
            }
        }
    }
}
