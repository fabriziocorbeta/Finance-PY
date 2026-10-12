package py.com.cdco.financespy.screens

import io.ktor.client.HttpClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.FamilySettingsDto
import py.com.cdco.financespy.api.dto.UserDto
import py.com.cdco.financespy.auth.AuthRepository
import py.com.cdco.financespy.auth.TokenStorage
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class SettingsFakeApi : FinancePyApi(HttpClient()) {
    var shouldFail = false
    override suspend fun fetchFamilySettings(): FamilySettingsDto {
        if (shouldFail) throw Exception("API Error")
        return FamilySettingsDto(
            id = "fam1",
            currency = "USD",
            locale = "en",
            date_format = "yyyy-MM-dd",
            month_start_day = 1,
            created_at = "2025-01-01",
            updated_at = "2025-01-01",
            name = "My Family",
            business_mode_enabled = true,
            current_user = UserDto(
                id = "user1",
                email = "test@example.com",
                first_name = "Test",
                role = "admin"
            ),
            users = emptyList()
        )
    }
}

class FakeTokenStorage : TokenStorage {
    override suspend fun save(accessToken: String, refreshToken: String) {}
    override suspend fun accessToken(): String? = null
    override suspend fun refreshToken(): String? = null
    override suspend fun clear() {}
}

@OptIn(ExperimentalCoroutinesApi::class)
class SettingsViewModelTest {
    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)
    private val fakeApi = SettingsFakeApi()

    // AuthRepository is a final class, so we instantiate it with a FakeTokenStorage
    private val fakeAuth = AuthRepository(HttpClient(), FakeTokenStorage())

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testLoadSettingsSuccess() = runTest {
        val viewModel = SettingsViewModel(this, fakeApi, fakeAuth)

        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertEquals("My Family", state.familyName)
        assertEquals(true, state.businessModeEnabled)
        assertEquals("user1", state.currentUser?.id)
    }

    @Test
    fun testLoadSettingsFailure() = runTest {
        fakeApi.shouldFail = true
        val viewModel = SettingsViewModel(this, fakeApi, fakeAuth)

        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertEquals("API Error", state.error)
    }

    @Test
    fun testLogout() = runTest {
        val viewModel = SettingsViewModel(this, fakeApi, fakeAuth)
        var loggedOutCallbackCalled = false

        viewModel.logout {
            loggedOutCallbackCalled = true
        }

        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals(true, loggedOutCallbackCalled)
    }
}
