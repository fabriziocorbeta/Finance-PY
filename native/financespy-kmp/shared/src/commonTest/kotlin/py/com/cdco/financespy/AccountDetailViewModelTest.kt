package py.com.cdco.financespy

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.BalanceSeriesDto
import py.com.cdco.financespy.api.dto.BalanceSeriesPointDto
import py.com.cdco.financespy.api.dto.BalanceSeriesTrendDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity
import py.com.cdco.financespy.screens.AccountDetailViewModel
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull

class AccountDetailFakeApi : FinancePyApi(io.ktor.client.HttpClient()) {
    var lastAccountId: String? = null
    var lastPeriod: String? = null

    override suspend fun fetchAccountBalanceSeries(accountId: String, period: String): BalanceSeriesDto {
        lastAccountId = accountId
        lastPeriod = period
        return BalanceSeriesDto(
            currency = "USD",
            period = period,
            series = listOf(
                BalanceSeriesPointDto(date = "2025-01-01", balance = 100.0),
                BalanceSeriesPointDto(date = "2025-01-02", balance = 150.0)
            ),
            trend = BalanceSeriesTrendDto(
                start_balance = 100.0,
                end_balance = 150.0,
                value = 50.0,
                percent = 50.0,
                direction = "up"
            )
        )
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class AccountDetailViewModelTest {
    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)
    private val fakeApi = AccountDetailFakeApi()

    private val dummyAccountDao = object : AccountDao {
        override fun observeAll(): Flow<List<AccountEntity>> = flowOf(
            listOf(
                AccountEntity(
                    id = "acc-123",
                    name = "Checking Account",
                    balanceCents = 15000,
                    cashBalanceCents = 15000,
                    currency = "USD",
                    classification = "asset",
                    accountType = "depository",
                    subtype = "checking",
                    status = "active",
                    updatedAt = "2025-01-01T00:00:00Z"
                )
            )
        )
        override suspend fun upsertAll(accounts: List<AccountEntity>) {}
        override suspend fun deleteAllExcept(ids: List<String>) {}
    }

    private val dummyEntryDao = object : EntryDao {
        override fun observeRecent(limit: Int): Flow<List<EntryEntity>> = flowOf(emptyList())
        override fun observeAll(): Flow<List<EntryEntity>> = flowOf(emptyList())
        override fun observeByAccountId(accountId: String): Flow<List<EntryEntity>> = flowOf(emptyList())
        override suspend fun upsertAll(entries: List<EntryEntity>) {}
        override suspend fun deleteStaleWithinWindow(activeIds: List<String>, windowStartDate: String) {}
    }

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testLoadsAccountDetailAndBalanceSeries() = testScope.runTest {
        val viewModel = AccountDetailViewModel(
            scope = this,
            accountId = "acc-123",
            accountDao = dummyAccountDao,
            entryDao = dummyEntryDao,
            api = fakeApi
        )

        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.state.value
        assertEquals("acc-123", state.account?.id)
        assertFalse(state.isLoadingSeries)
        assertNotNull(state.balanceSeries)
        assertEquals(2, state.balanceSeries?.series?.size)
        assertEquals("acc-123", fakeApi.lastAccountId)
        assertEquals("last_30_days", fakeApi.lastPeriod)
    }

    @Test
    fun testPeriodChange() = testScope.runTest {
        val viewModel = AccountDetailViewModel(
            scope = this,
            accountId = "acc-123",
            accountDao = dummyAccountDao,
            entryDao = dummyEntryDao,
            api = fakeApi
        )

        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.changePeriod("last_90_days")
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals("last_90_days", fakeApi.lastPeriod)
        assertEquals("last_90_days", viewModel.state.value.seriesPeriod)
    }
}
