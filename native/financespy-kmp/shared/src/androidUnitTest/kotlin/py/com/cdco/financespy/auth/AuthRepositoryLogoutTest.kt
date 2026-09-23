package py.com.cdco.financespy.auth

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.engine.mock.respondError
import io.ktor.client.request.forms.FormDataContent
import io.ktor.http.HttpStatusCode
import kotlinx.coroutines.test.runTest
import org.junit.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AuthRepositoryLogoutTest {

    private class FakeTokenStorage(
        var access: String? = "access_1",
        var refresh: String? = "refresh_1"
    ) : TokenStorage {
        var cleared = false
        override suspend fun save(accessToken: String, refreshToken: String) {
            access = accessToken
            refresh = refreshToken
        }
        override suspend fun accessToken(): String? = access
        override suspend fun refreshToken(): String? = refresh
        override suspend fun clear() {
            access = null
            refresh = null
            cleared = true
        }
    }

    @Test
    fun logoutRevokesBothTokensClearsStorageAndWipesLocalData() = runTest {
        val revokedTokens = mutableListOf<Pair<String?, String?>>()
        val engine = MockEngine { request ->
            val form = request.body as FormDataContent
            revokedTokens.add(form.formData["token"] to form.formData["token_type_hint"])
            respond("", HttpStatusCode.OK)
        }
        val tokens = FakeTokenStorage()
        var wiped = false
        val repo = AuthRepository(
            http = HttpClient(engine),
            tokens = tokens,
            wipeLocalData = { wiped = true }
        )

        repo.logout()

        assertEquals(2, revokedTokens.size)
        assertTrue(revokedTokens.any { it.first == "access_1" && it.second == "access_token" })
        assertTrue(revokedTokens.any { it.first == "refresh_1" && it.second == "refresh_token" })
        assertTrue(tokens.cleared)
        assertTrue(wiped)
    }

    @Test
    fun logoutClearsAndWipesEvenWhenRevokeFails() = runTest {
        val engine = MockEngine { respondError(HttpStatusCode.InternalServerError) }
        val tokens = FakeTokenStorage()
        var wiped = false
        val repo = AuthRepository(
            http = HttpClient(engine),
            tokens = tokens,
            wipeLocalData = { wiped = true }
        )

        repo.logout()

        assertTrue(tokens.cleared)
        assertTrue(wiped)
    }

    @Test
    fun logoutClearsAndDoesNotThrowWhenWipeLocalDataFails() = runTest {
        val engine = MockEngine { respond("", HttpStatusCode.OK) }
        val tokens = FakeTokenStorage()
        val repo = AuthRepository(
            http = HttpClient(engine),
            tokens = tokens,
            wipeLocalData = { error("Room blew up") }
        )

        repo.logout()

        assertTrue(tokens.cleared)
    }

    @Test
    fun logoutWithNoStoredTokensSkipsRevokeButStillWipes() = runTest {
        var revokeCalls = 0
        val engine = MockEngine { revokeCalls++; respond("", HttpStatusCode.OK) }
        val tokens = FakeTokenStorage(access = null, refresh = null)
        var wiped = false
        val repo = AuthRepository(
            http = HttpClient(engine),
            tokens = tokens,
            wipeLocalData = { wiped = true }
        )

        repo.logout()

        assertEquals(0, revokeCalls)
        assertTrue(tokens.cleared)
        assertTrue(wiped)
    }
}
