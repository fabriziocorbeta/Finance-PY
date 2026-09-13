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
import py.com.cdco.financespy.api.dto.GoalDto
import py.com.cdco.financespy.db.GoalDao
import py.com.cdco.financespy.db.GoalEntity
import py.com.cdco.financespy.screens.GoalsListViewModel
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull

class GoalsListFakeApi : FinancePyApi(io.ktor.client.HttpClient()) {
    var goalsToReturn: List<GoalDto> = emptyList()
    var shouldFail: Boolean = false

    override suspend fun fetchAllGoals(): List<GoalDto> {
        if (shouldFail) {
            throw RuntimeException("Network Error Goals")
        }
        return goalsToReturn
    }
}

class FakeGoalDao : GoalDao {
    val storedEntities = mutableListOf<GoalEntity>()

    override fun observeAll(): Flow<List<GoalEntity>> = flowOf(storedEntities)

    override suspend fun findById(id: String): GoalEntity? = storedEntities.find { it.id == id }

    override suspend fun upsertAll(goals: List<GoalEntity>) {
        goals.forEach { newEntity ->
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
class GoalsListViewModelTest {
    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)
    private val fakeApi = GoalsListFakeApi()
    private val fakeDao = FakeGoalDao()

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
        fakeApi.goalsToReturn = listOf(
            GoalDto(
                id = "goal-1",
                name = "Viaje Europa",
                target_amount = "2000",
                currency = "USD"
            )
        )

        val viewModel = GoalsListViewModel(
            scope = this,
            api = fakeApi,
            goalDao = fakeDao
        )

        viewModel.refresh()
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.state.value
        assertFalse(state.isLoading)
        assertNull(state.error)
        assertEquals(1, fakeDao.storedEntities.size)
        assertEquals("goal-1", fakeDao.storedEntities.first().id)
        assertEquals("Viaje Europa", fakeDao.storedEntities.first().name)
    }

    @Test
    fun testRefreshFailureSetsErrorState() = testScope.runTest {
        fakeApi.shouldFail = true

        val viewModel = GoalsListViewModel(
            scope = this,
            api = fakeApi,
            goalDao = fakeDao
        )

        viewModel.refresh()
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.state.value
        assertFalse(state.isLoading)
        assertEquals("Network Error Goals", state.error)
    }
}
