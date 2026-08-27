package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.sync.currentIsoDate

data class DonutSegmentUiModel(
    val id: String,
    val label: String,
    val color: String,
    val amount: Double
)

data class BudgetCategoryUiModel(
    val id: String,
    val name: String,
    val color: String,
    val budgetedSpending: Double,
    val actualSpending: Double,
    val availableToSpend: Double,
    val percentSpent: Float
)

data class BudgetDashboardUiState(
    val year: Int = 2026,
    val month: Int = 8, // 1..12
    val activeTab: String = "budgeted", // "budgeted" | "actuals"
    val isLoading: Boolean = false,
    val error: String? = null,
    val currency: String = "USD",
    val budgetedSpending: Double = 0.0,
    val actualSpending: Double = 0.0,
    val availableToSpend: Double = 0.0,
    val expectedIncome: Double = 0.0,
    val actualIncome: Double = 0.0,
    val allocatedSpending: Double = 0.0,
    val donutSegments: List<DonutSegmentUiModel> = emptyList(),
    val categories: List<BudgetCategoryUiModel> = emptyList()
)

class BudgetDashboardViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    initialYear: Int? = null,
    initialMonth: Int? = null
) {
    private val defaultYear: Int
    private val defaultMonth: Int

    init {
        val today = try {
            currentIsoDate().split("-").map { it.toInt() }
        } catch (_: Exception) {
            listOf(2026, 8)
        }
        defaultYear = initialYear ?: today.getOrElse(0) { 2026 }
        defaultMonth = initialMonth ?: today.getOrElse(1) { 8 }
    }

    private val _uiState = MutableStateFlow(BudgetDashboardUiState(year = defaultYear, month = defaultMonth))
    val uiState: StateFlow<BudgetDashboardUiState> = _uiState.asStateFlow()

    init {
        loadBudgetForSelectedMonth()
    }

    fun selectPreviousMonth() {
        var newMonth = _uiState.value.month - 1
        var newYear = _uiState.value.year
        if (newMonth < 1) {
            newMonth = 12
            newYear -= 1
        }
        _uiState.value = _uiState.value.copy(year = newYear, month = newMonth)
        loadBudgetForSelectedMonth()
    }

    fun selectNextMonth() {
        var newMonth = _uiState.value.month + 1
        var newYear = _uiState.value.year
        if (newMonth > 12) {
            newMonth = 1
            newYear += 1
        }
        _uiState.value = _uiState.value.copy(year = newYear, month = newMonth)
        loadBudgetForSelectedMonth()
    }

    fun setTab(tab: String) {
        _uiState.value = _uiState.value.copy(activeTab = tab)
    }

    fun refresh() {
        loadBudgetForSelectedMonth()
    }

    private fun loadBudgetForSelectedMonth() {
        scope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val allBudgets = api.fetchAllBudgets()
                val targetMonthStr = if (_uiState.value.month < 10) "0${_uiState.value.month}" else "${_uiState.value.month}"
                val targetPrefix = "${_uiState.value.year}-$targetMonthStr"

                val found = allBudgets.firstOrNull { budget ->
                    budget.start_date?.startsWith(targetPrefix) == true
                }

                if (found != null) {
                    val budgeted = found.budgeted_spending?.toDoubleOrNull() ?: 0.0
                    val expected = found.expected_income?.toDoubleOrNull() ?: 0.0
                    val actual = found.actual_spending ?: 0.0
                    val available = found.available_to_spend ?: (budgeted - actual)
                    val currency = found.currency ?: "USD"

                    val categoryList = found.categories?.map { c ->
                        BudgetCategoryUiModel(
                            id = c.id,
                            name = c.category_name ?: "Uncategorized",
                            color = c.category_color ?: "#6B7280",
                            budgetedSpending = c.budgeted_spending ?: 0.0,
                            actualSpending = c.actual_spending ?: 0.0,
                            availableToSpend = c.available_to_spend ?: 0.0,
                            percentSpent = (c.percent_spent ?: 0.0).toFloat()
                        )
                    } ?: emptyList()

                    val donutList = found.donut_segments?.map { d ->
                        DonutSegmentUiModel(
                            id = d.id,
                            label = d.id,
                            color = d.color,
                            amount = d.amount
                        )
                    } ?: buildFallbackDonutSegments(budgeted, actual, categoryList)

                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        currency = currency,
                        budgetedSpending = budgeted,
                        actualSpending = actual,
                        availableToSpend = available,
                        expectedIncome = expected,
                        categories = categoryList,
                        donutSegments = donutList
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        budgetedSpending = 0.0,
                        actualSpending = 0.0,
                        availableToSpend = 0.0,
                        expectedIncome = 0.0,
                        categories = emptyList(),
                        donutSegments = emptyList()
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Failed to fetch budget"
                )
            }
        }
    }

    private fun buildFallbackDonutSegments(
        budgeted: Double,
        actual: Double,
        categories: List<BudgetCategoryUiModel>
    ): List<DonutSegmentUiModel> {
        if (categories.isNotEmpty()) {
            val list = mutableListOf<DonutSegmentUiModel>()
            categories.forEach { c ->
                if (c.actualSpending > 0) {
                    list.add(
                        DonutSegmentUiModel(
                            id = c.id,
                            label = c.name,
                            color = c.color,
                            amount = c.actualSpending
                        )
                    )
                }
            }
            val remaining = budgeted - actual
            if (remaining > 0) {
                list.add(
                    DonutSegmentUiModel(
                        id = "unused",
                        label = "Unallocated",
                        color = "#E5E7EB",
                        amount = remaining
                    )
                )
            }
            return list
        } else if (budgeted > 0 || actual > 0) {
            return listOf(
                DonutSegmentUiModel(
                    id = "spent",
                    label = "Spent",
                    color = "#3B82F6",
                    amount = actual
                ),
                DonutSegmentUiModel(
                    id = "unused",
                    label = "Unallocated",
                    color = "#E5E7EB",
                    amount = (budgeted - actual).coerceAtLeast(0.0)
                )
            )
        }
        return emptyList()
    }
}
