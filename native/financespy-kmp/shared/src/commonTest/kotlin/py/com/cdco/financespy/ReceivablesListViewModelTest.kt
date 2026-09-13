package py.com.cdco.financespy

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.ReceivableDto
import py.com.cdco.financespy.db.ReceivableDao
import py.com.cdco.financespy.db.ReceivableEntity
import py.com.cdco.financespy.screens.ReceivablesListViewModel
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull

class ReceivablesListFakeApi : FinancePyApi(io.ktor.client.HttpClient()) {
    var receivablesToReturn: List<ReceivableDto> = emptyList()
    var shouldFail: Boolean = false

    override suspend fun fetchAllReceivables(): List<ReceivableDto> {
        if (shouldFail) {
            throw RuntimeException("Network Error Receivables")
        }
        return receivablesToReturn
    }
}

class FakeReceivableDao : ReceivableDao {
    val storedEntities = mutableListOf<ReceivableEntity>()

    override fun observeAll(): Flow<List<ReceivableEntity>> = flowOf(storedEntities)

    override fun observeById(id: String): Flow<ReceivableEntity?> = flowOf(storedEntities.find { it.id == id })

    override suspend fun getById(id: String): ReceivableEntity? = storedEntities.find { it.id == id }

    override suspend fun upsert(receivable: ReceivableEntity) {
        storedEntities.removeAll { it.id == receivable.id }
        storedEntities.add(receivable)
    }

    override suspend fun upsertAll(receivables: List<ReceivableEntity>) {
        receivables.forEach { newEntity ->
            storedEntities.removeAll { it.id == newEntity.id }
            storedEntities.add(newEntity)
        }
    }

    override suspend fun deleteById(id: String) {
        storedEntities.removeAll { it.id == id }
    }

    override suspend fun deleteAllExcept(ids: List<String>) {
        storedEntities.removeAll { !ids.contains(it.id) }
    }
}

@OptIn(ExperimentalCoroutinesApi::class)
class ReceivablesListViewModelTest {
    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)
    private val fakeApi = ReceivablesListFakeApi()
    private val fakeDao = FakeReceivableDao()

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testRefreshSuccessUpsertsEntities() = testScope.runTest {
        fakeApi.receivablesToReturn = listOf(
            ReceivableDto(
                id = "rec-1",
                name = "Préstamo Juan",
                total_amount = 1000.0,
                balance = 500.0,
                currency = "PYG"
            )
        )

        val viewModel = ReceivablesListViewModel(
            scope = this,
            api = fakeApi,
            receivableDao = fakeDao
        )

        viewModel.refresh()
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.state.value
        assertFalse(state.isLoading)
        assertNull(state.error)
        assertEquals(1, fakeDao.storedEntities.size)
        assertEquals("rec-1", fakeDao.storedEntities.first().id)
        assertEquals("Préstamo Juan", fakeDao.storedEntities.first().name)
    }

    @Test
    fun testRefreshFailureSetsErrorState() = testScope.runTest {
        fakeApi.shouldFail = true

        val viewModel = ReceivablesListViewModel(
            scope = this,
            api = fakeApi,
            receivableDao = fakeDao
        )

        viewModel.refresh()
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.state.value
        assertFalse(state.isLoading)
        assertEquals("Network Error Receivables", state.error)
    }
}
