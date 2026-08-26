package py.com.cdco.financespy

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.BudgetCategoryDto
import py.com.cdco.financespy.api.dto.BudgetDto
import py.com.cdco.financespy.screens.BudgetDashboardViewModel
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class FakeFinancePyApi : FinancePyApi(io.ktor.client.HttpClient()) {
    var budgetsToReturn = listOf<BudgetDto>()

    override suspend fun fetchAllBudgets(): List<BudgetDto> = budgetsToReturn
}

@OptIn(ExperimentalCoroutinesApi::class)
class BudgetDashboardViewModelTest {
    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)
    private val fakeApi = FakeFinancePyApi()

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testInitialMonthStateAndNavigation() = testScope.runTest {
        val viewModel = BudgetDashboardViewModel(
            scope = this,
            api = fakeApi,
            initialYear = 2026,
            initialMonth = 8
        )

        assertEquals(2026, viewModel.uiState.value.year)
        assertEquals(8, viewModel.uiState.value.month)

        viewModel.selectNextMonth()
        assertEquals(2026, viewModel.uiState.value.year)
        assertEquals(9, viewModel.uiState.value.month)

        viewModel.selectPreviousMonth()
        assertEquals(2026, viewModel.uiState.value.year)
        assertEquals(8, viewModel.uiState.value.month)

        viewModel.selectPreviousMonth()
        assertEquals(2026, viewModel.uiState.value.year)
        assertEquals(7, viewModel.uiState.value.month)
    }

    @Test
    fun testLoadingBudgetData() = testScope.runTest {
        fakeApi.budgetsToReturn = listOf(
            BudgetDto(
                id = "budget-1",
                start_date = "2026-08-01",
                end_date = "2026-08-31",
                budgeted_spending = "5000.0",
                expected_income = "6000.0",
                currency = "USD",
                actual_spending = 1500.0,
                available_to_spend = 3500.0,
                categories = listOf(
                    BudgetCategoryDto(
                        id = "cat-1",
                        category_id = "c1",
                        category_name = "Food & Dining",
                        category_color = "#F59E0B",
                        budgeted_spending = 1000.0,
                        actual_spending = 500.0,
                        available_to_spend = 500.0,
                        percent_spent = 50.0
                    )
                )
            )
        )

        val viewModel = BudgetDashboardViewModel(
            scope = this,
            api = fakeApi,
            initialYear = 2026,
            initialMonth = 8
        )

        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.uiState.value
        assertFalse(state.isLoading)
        assertEquals("USD", state.currency)
        assertEquals(5000.0, state.budgetedSpending)
        assertEquals(1500.0, state.actualSpending)
        assertEquals(3500.0, state.availableToSpend)
        assertEquals(1, state.categories.size)
        assertEquals("Food & Dining", state.categories[0].name)
        assertEquals(50.0f, state.categories[0].percentSpent)
    }
}
