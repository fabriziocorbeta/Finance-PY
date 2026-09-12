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
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.CashflowSankeyDto
import py.com.cdco.financespy.api.dto.DashboardDto
import py.com.cdco.financespy.api.dto.GoalDto
import py.com.cdco.financespy.api.dto.InvestmentSummaryDto
import py.com.cdco.financespy.api.dto.NetWorthDto
import py.com.cdco.financespy.api.dto.OutflowsDonutDto
import py.com.cdco.financespy.api.dto.PeriodDto
import py.com.cdco.financespy.api.dto.ReceivableDto
import py.com.cdco.financespy.api.dto.RuleDto
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity
import py.com.cdco.financespy.db.RuleDao
import py.com.cdco.financespy.db.RuleEntity
import py.com.cdco.financespy.db.RuleRunDao
import py.com.cdco.financespy.db.RuleRunEntity
import py.com.cdco.financespy.db.TransactionDao
import py.com.cdco.financespy.db.TransactionEntity
import py.com.cdco.financespy.screens.DashboardViewModel
import py.com.cdco.financespy.sync.SyncEngine
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull

class DashboardFakeApi : FinancePyApi(io.ktor.client.HttpClient()) {
    var dashboardToReturn: DashboardDto? = null
    var shouldFail: Boolean = false
    var lastRequestedPeriod: String? = null

    override suspend fun fetchAllAccounts(): List<AccountDto> = emptyList()
    override suspend fun fetchRecentTransactions(startDate: String): List<TransactionListItemDto> = emptyList()
    override suspend fun fetchAllRules(): List<RuleDto> = emptyList()
    override suspend fun fetchAllGoals(): List<GoalDto> = emptyList()
    override suspend fun fetchAllReceivables(): List<ReceivableDto> = emptyList()

    override suspend fun fetchDashboard(period: String?): DashboardDto {
        lastRequestedPeriod = period
        if (shouldFail) {
            throw RuntimeException("Network Error")
        }
        return dashboardToReturn ?: DashboardDto(
            greeting_name = "Fabrizio",
            currency = "PYG",
            period = PeriodDto(key = period ?: "current_month", label = "Mes actual"),
            net_worth = NetWorthDto(amount = 1000000.0, currency = "PYG"),
            cashflow_sankey = CashflowSankeyDto(),
            outflows_donut = OutflowsDonutDto(),
            investment_summary = InvestmentSummaryDto(portfolio_value = 500000.0)
        )
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class DashboardViewModelTest {
    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)
    private val fakeApi = DashboardFakeApi()

    private val dummyAccountDao = object : AccountDao {
        override fun observeAll(): Flow<List<AccountEntity>> = flowOf(emptyList())
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

    private val dummyTransactionDao = object : TransactionDao {
        override suspend fun upsertAll(transactions: List<TransactionEntity>) {}
        override suspend fun findById(id: String): TransactionEntity? = null
    }

    private val dummyRuleDao = object : RuleDao {
        override fun observeAll(): Flow<List<RuleEntity>> = flowOf(emptyList())
        override suspend fun findById(id: String): RuleEntity? = null
        override suspend fun upsertAll(rules: List<RuleEntity>) {}
        override suspend fun deleteById(id: String) {}
        override suspend fun deleteAllExcept(ids: List<String>) {}
    }

    private val dummyRuleRunDao = object : RuleRunDao {
        override fun observeByRuleId(ruleId: String): Flow<List<RuleRunEntity>> = flowOf(emptyList())
        override suspend fun upsertAll(ruleRuns: List<RuleRunEntity>) {}
    }

    private val syncEngine = SyncEngine(
        api = fakeApi,
        accountDao = dummyAccountDao,
        entryDao = dummyEntryDao,
        transactionDao = dummyTransactionDao,
        ruleDao = dummyRuleDao,
        ruleRunDao = dummyRuleRunDao,
        currentDateProvider = { "2026-08-10" }
    )

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testLoadingDashboardData() = testScope.runTest {
        fakeApi.dashboardToReturn = DashboardDto(
            greeting_name = "Fabrizio",
            currency = "PYG",
            period = PeriodDto(key = "current_month", label = "August 2026"),
            net_worth = NetWorthDto(amount = 5000000.0, currency = "PYG")
        )

        val viewModel = DashboardViewModel(
            scope = this,
            syncEngine = syncEngine,
            api = fakeApi
        )

        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.state.value
        assertFalse(state.isSyncing)
        assertNull(state.syncError)
        assertNotNull(state.dashboard)
        assertEquals("Fabrizio", state.dashboard?.greeting_name)
        assertEquals(5000000.0, state.dashboard?.net_worth?.amount)
        assertEquals("current_month", state.selectedPeriod)
    }

    @Test
    fun testPeriodSelection() = testScope.runTest {
        val viewModel = DashboardViewModel(
            scope = this,
            syncEngine = syncEngine,
            api = fakeApi
        )

        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.selectPeriod("last_30_days")
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals("last_30_days", fakeApi.lastRequestedPeriod)
        assertEquals("last_30_days", viewModel.state.value.selectedPeriod)

        viewModel.selectPeriod("current_year")
        testDispatcher.scheduler.advanceUntilIdle()

        assertEquals("current_year", fakeApi.lastRequestedPeriod)
        assertEquals("current_year", viewModel.state.value.selectedPeriod)
    }

    @Test
    fun testErrorHandling() = testScope.runTest {
        fakeApi.shouldFail = true

        val viewModel = DashboardViewModel(
            scope = this,
            syncEngine = syncEngine,
            api = fakeApi
        )

        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.state.value
        assertFalse(state.isSyncing)
        assertEquals("Network Error", state.syncError)
        assertNull(state.dashboard)
    }
}
