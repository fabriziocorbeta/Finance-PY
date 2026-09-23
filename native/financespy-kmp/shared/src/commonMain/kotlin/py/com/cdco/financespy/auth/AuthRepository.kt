package py.com.cdco.financespy.auth

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.forms.submitForm
import io.ktor.http.Parameters
import kotlinx.serialization.Serializable
import py.com.cdco.financespy.network.ApiClient

private const val CLIENT_ID = "Ti8y1yGMsJVyNv35wsWE2taV7NR4B3zdKduf7E5IZEM"
private const val REDIRECT_URI = "financespy://oauth/callback"

@Serializable
data class TokenResponse(
    val access_token: String,
    val refresh_token: String,
    val token_type: String,
    val expires_in: Int
)

class AuthRepository(
    private val http: HttpClient,
    private val tokens: TokenStorage,
    private val pkce: PkceGenerator = PkceGenerator(),
    // Wipes platform-local data (Room tables, offline queue/caches, Wallet
    // pending captures, owner-scope marker) on logout. Injected instead of
    // implemented here because AuthRepository is commonMain and has no
    // access to Room/Context -- see MainActivity for the Android wiring.
    // Never allowed to block/abort logout: any failure here is swallowed.
    private val wipeLocalData: suspend () -> Unit = {}
) {
    private var pendingVerifier: String? = null

    fun buildAuthorizationUrl(): String {
        val verifier = pkce.generateVerifier()
        pendingVerifier = verifier
        val challenge = pkce.challengeFor(verifier)
        return "${ApiClient.BASE_URL}/oauth/authorize" +
            "?client_id=$CLIENT_ID" +
            "&redirect_uri=$REDIRECT_URI" +
            "&response_type=code" +
            "&scope=read_write" +
            "&code_challenge=$challenge" +
            "&code_challenge_method=S256"
    }

    suspend fun exchangeCode(code: String): Result<Unit> = runCatching {
        val verifier = pendingVerifier ?: error("No hay un flujo de login en curso (falta buildAuthorizationUrl antes)")
        val response: TokenResponse = http.submitForm(
            url = "${ApiClient.BASE_URL}/oauth/token",
            formParameters = Parameters.build {
                append("grant_type", "authorization_code")
                append("client_id", CLIENT_ID)
                append("code", code)
                append("redirect_uri", REDIRECT_URI)
                append("code_verifier", verifier)
            }
        ).body()
        tokens.save(response.access_token, response.refresh_token)
        pendingVerifier = null
    }

    suspend fun isLoggedIn(): Boolean = tokens.accessToken() != null

    /**
     * Full sign-out, in order:
     * 1. Best-effort revoke of both tokens server-side. Network/server
     *    failure (offline, etc.) is swallowed -- logout must never get
     *    stuck waiting on a call that will never succeed.
     * 2. Always clear the local token store, even if revoke failed.
     * 3. Wipe platform-local data (see [wipeLocalData]). Also never allowed
     *    to throw out of here.
     */
    suspend fun logout() {
        val access = tokens.accessToken()
        val refresh = tokens.refreshToken()
        revokeToken(access, "access_token")
        revokeToken(refresh, "refresh_token")
        tokens.clear()
        runCatching { wipeLocalData() }
    }

    private suspend fun revokeToken(token: String?, tokenTypeHint: String) {
        if (token == null) return
        runCatching {
            http.submitForm(
                url = "${ApiClient.BASE_URL}/oauth/revoke",
                formParameters = Parameters.build {
                    append("token", token)
                    append("token_type_hint", tokenTypeHint)
                    append("client_id", CLIENT_ID)
                }
            )
        }
    }
}
