package py.com.cdco.financespy.network

import io.ktor.client.HttpClient
import io.ktor.client.HttpClientConfig
import io.ktor.client.plugins.HttpRequestRetry
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.plugins.logging.LogLevel
import io.ktor.client.plugins.logging.Logging
import io.ktor.client.request.header
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import py.com.cdco.financespy.api.dto.AppVersionInfo
import py.com.cdco.financespy.auth.TokenStorage

object ApiClient {
    const val BASE_URL = "https://finance.cd-co.com.py"

    fun create(tokenStorage: TokenStorage, appVersion: AppVersionInfo? = null): HttpClient = createPlatformClient(tokenStorage) {
        // A 4xx/5xx must fail the call. Without this, a JSON error body (401, 429...) was decoded
        // into a DTO made only of defaults and shown as real, empty data ("no accounts").
        expectSuccess = true
        install(ContentNegotiation) {
            json(Json { ignoreUnknownKeys = true; isLenient = true })
        }
        install(Logging) { level = if (isDebugBuild) LogLevel.INFO else LogLevel.NONE }
        installTransientGatewayRetry()
        install(HttpTimeout) {
            requestTimeoutMillis = 30_000
            connectTimeoutMillis = 15_000
            socketTimeoutMillis = 30_000
        }
        defaultRequest {
            url(BASE_URL)
            if (appVersion != null) {
                header("X-Platform", appVersion.platform)
                header("X-App-Version", appVersion.versionName)
                header("X-App-Build", appVersion.versionCode.toString())
                header(HttpHeaders.UserAgent, "FinancePY-${appVersion.platform}/${appVersion.versionName} (${appVersion.versionCode})")
            }
        }
    }
}

/** Gateway statuses that mean "the tunnel/proxy blinked", not "the app rejected this". */
internal val TRANSIENT_GATEWAY_STATUSES = setOf(502, 503, 504)

/**
 * The server sits behind a Cloudflare tunnel that occasionally drops for a few
 * seconds; every request in that window comes back as a Cloudflare 502/503/504.
 * Without a retry that surfaced as a raw error on whichever screen happened to
 * be loading. Only read-only requests (GET/HEAD) are retried: repeating a POST
 * could create the same sale or transaction twice. Waits 1s, 2s, 4s, 8s (~15s
 * in total), which covers the reconnects observed in production (~13s).
 *
 * Retry-After is ignored on purpose: Cloudflare sends 60s, far longer than the
 * outage actually lasts.
 */
internal fun HttpClientConfig<*>.installTransientGatewayRetry(
    maxRetries: Int = 4,
    delayForRetry: (Int) -> Long = { retry -> minOf(1_000L shl (retry - 1), 8_000L) }
) {
    install(HttpRequestRetry) {
        retryIf(maxRetries) { request, response ->
            (request.method == HttpMethod.Get || request.method == HttpMethod.Head) &&
                response.status.value in TRANSIENT_GATEWAY_STATUSES
        }
        // The plugin's default also retries on exceptions for every method;
        // keep that off so a write is never sent twice.
        retryOnExceptionIf(maxRetries) { _, _ -> false }
        delayMillis(respectRetryAfterHeader = false) { retry -> delayForRetry(retry) }
    }
}

expect fun createPlatformClient(tokenStorage: TokenStorage, config: HttpClientConfig<*>.() -> Unit): HttpClient

expect val isDebugBuild: Boolean
