package py.com.cdco.financespy.screens

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
import py.com.cdco.financespy.api.dto.ReceivableDto
import py.com.cdco.financespy.db.ReceivableDao
import py.com.cdco.financespy.db.ReceivableEntity
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals

private fun accountDto(id: String, accountType: String, status: String = "active") = AccountDto(
    id = id,
    name = id,
    balance_cents = 0,
    cash_balance_cents = 0,
    currency = "PYG",
    classification = "asset",
    account_type = accountType,
    status = status,
    updated_at = "2026-08-25T12:00:00Z"
)

// Mirrors the real GET /api/v1/accounts envelope shape (accounts/pagination,
// see app/views/api/v1/accounts/index.json.jbuilder) -- fetchAllAccounts()
// already decodes it internally, so the fake just returns the final list
// directly, same pattern as AccountDetailFakeApi.
private class ReceivableDetailFakeApi(
    private val accounts: List<AccountDto>,
    private val receivable: ReceivableDto
) : FinancePyApi(io.ktor.client.HttpClient()) {
    override suspend fun fetchAllAccounts(): List<AccountDto> = accounts
    override suspend fun fetchReceivable(id: String): ReceivableDto = receivable
}

private class FakeReceivableDao(private val entity: ReceivableEntity) : ReceivableDao {
    override fun observeAll(): Flow<List<ReceivableEntity>> = flowOf(listOf(entity))
    override fun observeById(id: String): Flow<ReceivableEntity?> = flowOf(entity)
    override suspend fun getById(id: String): ReceivableEntity? = entity
    override suspend fun upsertAll(receivables: List<ReceivableEntity>) {}
    override suspend fun upsert(receivable: ReceivableEntity) {}
    override suspend fun deleteAllExcept(ids: List<String>) {}
    override suspend fun deleteById(id: String) {}
}

private fun receivableEntity(id: String) = ReceivableEntity(
    id = id,
    name = "Préstamo",
    totalAmount = 1000.0,
    balance = 1000.0,
    balanceCents = 100000,
    originalBalance = 1000.0,
    originalBalanceCents = 100000,
    paidAmount = 0.0,
    paidAmountCents = 0,
    percentPaid = 0.0,
    installmentCount = null,
    dueDay = null,
    currency = "PYG",
    notes = null,
    updatedAt = "2026-08-25T12:00:00Z"
)

@OptIn(ExperimentalCoroutinesApi::class)
class ReceivableDetailViewModelTest {
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

    @Test
    fun openPaymentDialogFiltersDepositoryAccountsCaseInsensitively() = testScope.runTest {
        // One lowercase "depository" (matches the real API payload), one
        // "Depository" exact case, one "Credit" (must be excluded) and one
        // inactive depository account (must be excluded too).
        val accounts = listOf(
            accountDto("acc1", "depository"),
            accountDto("acc2", "Depository"),
            accountDto("acc3", "Credit"),
            accountDto("acc4", "depository", status = "inactive")
        )
        val fakeApi = ReceivableDetailFakeApi(
            accounts = accounts,
            receivable = ReceivableDto(id = "rec-1", account_id = "acc1")
        )
        val viewModel = ReceivableDetailViewModel(
            scope = this,
            receivableId = "rec-1",
            api = fakeApi,
            receivableDao = FakeReceivableDao(receivableEntity("rec-1"))
        )

        viewModel.openPaymentDialog()
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.state.value
        assertEquals(null, state.paymentError)
        assertEquals(2, state.paymentAccounts.size)
        assertEquals(setOf("acc1", "acc2"), state.paymentAccounts.map { it.id }.toSet())
        assertEquals("acc1", state.receivableAccountId)
    }
}
