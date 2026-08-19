package py.com.cdco.financespy.network

import io.ktor.client.HttpClient
import io.ktor.client.HttpClientConfig
import io.ktor.client.engine.okhttp.OkHttp
import io.ktor.client.plugins.api.createClientPlugin
import io.ktor.client.request.header
import kotlinx.coroutines.runBlocking
import py.com.cdco.financespy.auth.TokenStorage

actual fun createPlatformClient(tokenStorage: TokenStorage, config: HttpClientConfig<*>.() -> Unit): HttpClient {
    val bearerPlugin = createClientPlugin("BearerAuthPlugin") {
        onRequest { request, _ ->
            val token = runBlocking { tokenStorage.accessToken() }
            if (token != null) request.header("Authorization", "Bearer $token")
        }
    }
    return HttpClient(OkHttp) {
        config()
        install(bearerPlugin)
    }
}
