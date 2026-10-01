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
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.screens.DebtsListViewModel
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

private fun account(
    id: String,
    name: String,
    balanceCents: Long,
    currency: String,
    classification: String,
    accountType: String
) = AccountEntity(
    id = id,
    name = name,
    balanceCents = balanceCents,
    cashBalanceCents = balanceCents,
    currency = currency,
    classification = classification,
    accountType = accountType,
    subtype = null,
    status = "active",
    updatedAt = "2026-09-30T00:00:00Z"
)

@OptIn(ExperimentalCoroutinesApi::class)
class DebtsListViewModelTest {
    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    private fun daoWith(accounts: List<AccountEntity>) = object : AccountDao {
        override fun observeAll(): Flow<List<AccountEntity>> = flowOf(accounts)
        override suspend fun upsertAll(accounts: List<AccountEntity>) {}
        override suspend fun deleteAllExcept(ids: List<String>) {}
    }

    @Test
    fun onlyIncludesLiabilityAccounts() = testScope.runTest {
        val dao = daoWith(
            listOf(
                account("acc-1", "Cuenta corriente", 500_000, "PYG", "asset", "Depository"),
                account("acc-2", "Tarjeta Visa", 1_200_000, "PYG", "liability", "CreditCard"),
                account("acc-3", "Préstamo auto", 30_000_000, "PYG", "liability", "Loan")
            )
        )

        val viewModel = DebtsListViewModel(scope = this, accountDao = dao)
        testDispatcher.scheduler.advanceUntilIdle()

        val debts = viewModel.debts.value
        assertEquals(2, debts.size)
        assertTrue(debts.none { it.classification == "asset" })
        assertTrue(debts.any { it.id == "acc-2" })
        assertTrue(debts.any { it.id == "acc-3" })
    }

    @Test
    fun totalsAreGroupedByCurrency() = testScope.runTest {
        val dao = daoWith(
            listOf(
                account("acc-1", "Tarjeta Visa", 1_200_000, "PYG", "liability", "CreditCard"),
                account("acc-2", "Préstamo auto", 30_000_000, "PYG", "liability", "Loan"),
                account("acc-3", "Tarjeta USD", 500, "USD", "liability", "CreditCard")
            )
        )

        val viewModel = DebtsListViewModel(scope = this, accountDao = dao)
        testDispatcher.scheduler.advanceUntilIdle()

        val totals = viewModel.totalOwedByCurrency.value
        assertEquals(31_200_000L, totals["PYG"])
        assertEquals(500L, totals["USD"])
    }

    @Test
    fun emptyWhenNoLiabilities() = testScope.runTest {
        val dao = daoWith(
            listOf(account("acc-1", "Cuenta corriente", 500_000, "PYG", "asset", "Depository"))
        )

        val viewModel = DebtsListViewModel(scope = this, accountDao = dao)
        testDispatcher.scheduler.advanceUntilIdle()

        assertTrue(viewModel.debts.value.isEmpty())
        assertTrue(viewModel.totalOwedByCurrency.value.isEmpty())
    }
}
