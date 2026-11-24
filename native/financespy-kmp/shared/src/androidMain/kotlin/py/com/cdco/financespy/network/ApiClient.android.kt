package py.com.cdco.financespy.network

import io.ktor.client.HttpClient
import io.ktor.client.HttpClientConfig
import io.ktor.client.call.body
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.ClientRequestException
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.auth.Auth
import io.ktor.client.plugins.auth.providers.BearerTokens
import io.ktor.client.plugins.auth.providers.bearer
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.forms.submitForm
import io.ktor.http.Parameters
import io.ktor.http.encodedPath
import io.ktor.serialization.kotlinx.json.json
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.Json
import py.com.cdco.financespy.auth.TokenRefreshLock
import py.com.cdco.financespy.auth.TokenResponse
import py.com.cdco.financespy.auth.TokenStorage
import py.com.cdco.financespy.shared.BuildConfig

private const val CLIENT_ID = "Ti8y1yGMsJVyNv35wsWE2taV7NR4B3zdKduf7E5IZEM"

actual fun createPlatformClient(tokenStorage: TokenStorage, config: HttpClientConfig<*>.() -> Unit): HttpClient {
    return HttpClient(OkHttp) {
        config()
        install(Auth) {
            bearer {
                // Only attach Bearer tokens to authenticated /api/ paths (never /oauth/*).
                sendWithoutRequest { request ->
                    request.url.encodedPath.startsWith("/api/") &&
                        request.url.encodedPath != "/api/v1/app_config"
                }
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
                    val staleAccessToken = oldTokens?.accessToken
                    TokenRefreshLock.mutex.withLock {
                        // Re-check storage inside the lock: another coroutine or
                        // WalletCaptureHandler may have already rotated tokens.
                        val currentAccess = tokenStorage.accessToken()
                        val currentRefresh = tokenStorage.refreshToken()
                        if (!currentAccess.isNullOrBlank() &&
                            !currentRefresh.isNullOrBlank() &&
                            staleAccessToken != null &&
                            currentAccess != staleAccessToken
                        ) {
                            return@withLock BearerTokens(currentAccess, currentRefresh)
                        }

                        val refreshToken = currentRefresh ?: return@withLock null

                        val refreshClient = HttpClient(OkHttp) {
                            expectSuccess = true
                            install(ContentNegotiation) {
                                json(Json { ignoreUnknownKeys = true; isLenient = true })
                            }
                            install(HttpTimeout) {
                                requestTimeoutMillis = 15_000
                                connectTimeoutMillis = 10_000
                                socketTimeoutMillis = 15_000
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
                            // Clear stored tokens only on permanent 400/401 invalid_grant
                            // and only if the refresh token wasn't rotated concurrently.
                            val status = e.response.status.value
                            if ((status == 400 || status == 401) && tokenStorage.refreshToken() == refreshToken) {
                                tokenStorage.clear()
                            }
                            null
                        } catch (e: Exception) {
                            // Network/timeout/5xx error: keep tokens intact for retry.
                            null
                        } finally {
                            refreshClient.close()
                        }
                    }
                }
            }
        }
    }
}

actual val isDebugBuild: Boolean = BuildConfig.DEBUG
