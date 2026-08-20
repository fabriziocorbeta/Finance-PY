package py.com.cdco.financespy.network

import io.ktor.client.HttpClient
import io.ktor.client.HttpClientConfig
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.plugins.defaultRequest
import io.ktor.client.plugins.logging.LogLevel
import io.ktor.client.plugins.logging.Logging
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json
import py.com.cdco.financespy.auth.TokenStorage

object ApiClient {
    const val BASE_URL = "https://finance.cd-co.com.py"

    fun create(tokenStorage: TokenStorage): HttpClient = createPlatformClient(tokenStorage) {
        install(ContentNegotiation) {
            json(Json { ignoreUnknownKeys = true; isLenient = true })
        }
        install(Logging) { level = LogLevel.INFO }
        install(HttpTimeout) {
            requestTimeoutMillis = 30_000
            connectTimeoutMillis = 30_000
            socketTimeoutMillis = 30_000
        }
        defaultRequest {
            url(BASE_URL)
        }
    }
}

expect fun createPlatformClient(tokenStorage: TokenStorage, config: HttpClientConfig<*>.() -> Unit): HttpClient
