package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.sync.currentIsoDate

enum class BudgetCategoryStatus {
    OVER_BUDGET,
    NEAR_LIMIT,
    ON_TRACK
}

data class SuggestedDailyUiModel(
    val amount: Double,
    val amountCents: Long,
    val daysRemaining: Int
)

data class DonutSegmentUiModel(
    val id: String,
    val label: String,
    val color: String,
    val amount: Double
)

data class BudgetCategoryUiModel(
    val id: String,
    val budgetId: String,
    val categoryId: String,
    val name: String,
    val color: String,
    val icon: String?,
    val parentId: String?,
    val isSubcategory: Boolean,
    val inheritsParentBudget: Boolean,
    val budgetedSpending: Double,
    val budgetedSpendingCents: Long,
    val actualSpending: Double,
    val actualSpendingCents: Long,
    val availableToSpend: Double,
    val availableToSpendCents: Long,
    val percentSpent: Float,
    val barWidthPercent: Float,
    val status: BudgetCategoryStatus,
    val statusAmountText: String,
    val avgMonthlyExpense: Double,
    val medianMonthlyExpense: Double,
    val suggestedDailySpending: SuggestedDailyUiModel?
)

data class BudgetCategoryGroupUiModel(
    val parentCategory: BudgetCategoryUiModel,
    val subcategories: List<BudgetCategoryUiModel>
)

data class BudgetDashboardUiState(
    val year: Int = 2026,
    val month: Int = 8, // 1..12
    val budgetParam: String = "2026-08",
    val budgetId: String? = null,
    val budgetName: String = "",
    val initialized: Boolean = true,
    val isCurrentMonth: Boolean = false,
    val previousBudgetParam: String? = null,
    val nextBudgetParam: String? = null,
    val sourceBudgetId: String? = null,
    val sourceBudgetName: String? = null,

    val activeTab: String = "budgeted", // "budgeted" | "actuals"
    val categoryFilterTab: String = "all", // "all" | "over_budget" | "on_track"
    val isLoading: Boolean = false,
    val error: String? = null,

    val currency: String = "USD",
    val budgetedSpending: Double = 0.0,
    val actualSpending: Double = 0.0,
    val availableToSpend: Double = 0.0,
    val expectedIncome: Double = 0.0,
    val actualIncome: Double = 0.0,
    val allocatedSpending: Double = 0.0,
    val availableToAllocate: Double = 0.0,
    val allocatedPercent: Double = 0.0,
    val allocationsValid: Boolean = true,
    val percentOfBudgetSpent: Double = 0.0,
    val actualIncomePercent: Double = 0.0,
    val remainingExpectedIncome: Double = 0.0,
    val surplusPercent: Double = 0.0,

    val donutSegments: List<DonutSegmentUiModel> = emptyList(),
    val categories: List<BudgetCategoryUiModel> = emptyList(),
    val categoryGroups: List<BudgetCategoryGroupUiModel> = emptyList(),
    val hasOverBudgetCategories: Boolean = false,

    // Selected category for detail sheet/modal
    val selectedCategory: BudgetCategoryUiModel? = null,
    val selectedCategoryRecentTransactions: List<TransactionListItemDto> = emptyList(),
    val isLoadingCategoryTransactions: Boolean = false,

    // Month picker dialog state
    val showMonthPicker: Boolean = false
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
        val prevParam = _uiState.value.previousBudgetParam
        if (prevParam != null && prevParam.contains("-")) {
            val parts = prevParam.split("-")
            val y = parts.getOrNull(0)?.toIntOrNull()
            val m = parts.getOrNull(1)?.toIntOrNull()
            if (y != null && m != null) {
                _uiState.value = _uiState.value.copy(year = y, month = m, budgetParam = prevParam)
                loadBudgetForSelectedMonth()
                return
            }
        }
        var newMonth = _uiState.value.month - 1
        var newYear = _uiState.value.year
        if (newMonth < 1) {
            newMonth = 12
            newYear -= 1
        }
        val targetParam = "$newYear-${if (newMonth < 10) "0$newMonth" else "$newMonth"}"
        _uiState.value = _uiState.value.copy(year = newYear, month = newMonth, budgetParam = targetParam)
        loadBudgetForSelectedMonth()
    }

    fun selectNextMonth() {
        val nextParam = _uiState.value.nextBudgetParam
        if (nextParam != null && nextParam.contains("-")) {
            val parts = nextParam.split("-")
            val y = parts.getOrNull(0)?.toIntOrNull()
            val m = parts.getOrNull(1)?.toIntOrNull()
            if (y != null && m != null) {
                _uiState.value = _uiState.value.copy(year = y, month = m, budgetParam = nextParam)
                loadBudgetForSelectedMonth()
                return
            }
        }
        var newMonth = _uiState.value.month + 1
        var newYear = _uiState.value.year
        if (newMonth > 12) {
            newMonth = 1
            newYear += 1
        }
        val targetParam = "$newYear-${if (newMonth < 10) "0$newMonth" else "$newMonth"}"
        _uiState.value = _uiState.value.copy(year = newYear, month = newMonth, budgetParam = targetParam)
        loadBudgetForSelectedMonth()
    }

    fun jumpToToday() {
        val today = try {
            currentIsoDate().split("-").map { it.toInt() }
        } catch (_: Exception) {
            listOf(2026, 8)
        }
        val y = today.getOrElse(0) { 2026 }
        val m = today.getOrElse(1) { 8 }
        val targetParam = "$y-${if (m < 10) "0$m" else "$m"}"
        _uiState.value = _uiState.value.copy(year = y, month = m, budgetParam = targetParam)
        loadBudgetForSelectedMonth()
    }

    fun selectMonth(year: Int, month: Int) {
        val targetParam = "$year-${if (month < 10) "0$month" else "$month"}"
        _uiState.value = _uiState.value.copy(year = year, month = month, budgetParam = targetParam, showMonthPicker = false)
        loadBudgetForSelectedMonth()
    }

    fun toggleMonthPicker(show: Boolean) {
        _uiState.value = _uiState.value.copy(showMonthPicker = show)
    }

    fun setTab(tab: String) {
        _uiState.value = _uiState.value.copy(activeTab = tab)
    }

    fun setCategoryFilterTab(filter: String) {
        _uiState.value = _uiState.value.copy(categoryFilterTab = filter)
    }

    fun selectCategory(category: BudgetCategoryUiModel?) {
        _uiState.value = _uiState.value.copy(selectedCategory = category, selectedCategoryRecentTransactions = emptyList())
        if (category != null) {
            loadCategoryTransactions(category)
        }
    }

    fun refresh() {
        loadBudgetForSelectedMonth()
    }

    fun copyPreviousBudget() {
        val sourceId = _uiState.value.sourceBudgetId
        val currBudgetId = _uiState.value.budgetId
        if (sourceId != null && currBudgetId != null) {
            scope.launch {
                _uiState.value = _uiState.value.copy(isLoading = true, error = null)
                try {
                    val sourceBudget = api.fetchBudget(sourceId)
                    val sourceCats = sourceBudget.categories ?: emptyList()
                    val currBudget = api.fetchBudget(currBudgetId)
                    val currCats = currBudget.categories ?: emptyList()

                    for (sc in sourceCats) {
                        if (sc.budgeted_spending != null && sc.budgeted_spending > 0) {
                            val match = currCats.firstOrNull { it.category_id == sc.category_id }
                            if (match != null) {
                                api.updateBudgetCategory(
                                    budgetId = currBudgetId,
                                    categoryId = match.id,
                                    budgetedSpending = sc.budgeted_spending
                                )
                            }
                        }
                    }
                    loadBudgetForSelectedMonth()
                } catch (e: Exception) {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        error = e.message ?: "Error al copiar del mes anterior"
                    )
                }
            }
        }
    }

    fun startFromScratch() {
        _uiState.value = _uiState.value.copy(initialized = true)
    }

    private fun loadCategoryTransactions(category: BudgetCategoryUiModel) {
        scope.launch {
            _uiState.value = _uiState.value.copy(isLoadingCategoryTransactions = true)
            try {
                val targetMonthStr = if (_uiState.value.month < 10) "0${_uiState.value.month}" else "${_uiState.value.month}"
                val startDate = "${_uiState.value.year}-$targetMonthStr-01"
                val endDate = "${_uiState.value.year}-$targetMonthStr-31"

                val txs = api.fetchTransactions(
                    startDate = startDate,
                    endDate = endDate,
                    categoryId = category.categoryId
                )
                _uiState.value = _uiState.value.copy(
                    isLoadingCategoryTransactions = false,
                    selectedCategoryRecentTransactions = txs.take(3)
                )
            } catch (_: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoadingCategoryTransactions = false,
                    selectedCategoryRecentTransactions = emptyList()
                )
            }
        }
    }

    private fun loadBudgetForSelectedMonth() {
        scope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val targetMonthStr = if (_uiState.value.month < 10) "0${_uiState.value.month}" else "${_uiState.value.month}"
                val targetPrefix = "${_uiState.value.year}-$targetMonthStr"

                val allBudgets = try { api.fetchAllBudgets() } catch (_: Exception) { emptyList() }
                val foundSummary = allBudgets.firstOrNull { budget ->
                    budget.start_date?.startsWith(targetPrefix) == true || budget.param == targetPrefix
                }

                val found = if (foundSummary?.id != null) {
                    try { api.fetchBudget(foundSummary.id) } catch (_: Exception) { foundSummary }
                } else {
                    try { api.fetchBudget(targetPrefix) } catch (_: Exception) { foundSummary }
                }

                if (found != null) {
                    val budgeted = found.budgeted_spending ?: 0.0
                    val expected = found.expected_income ?: 0.0
                    val actual = found.actual_spending ?: 0.0
                    val available = found.available_to_spend ?: (budgeted - actual)
                    val currency = found.currency ?: "USD"
                    val allocated = found.allocated_spending ?: 0.0
                    val availToAllocate = found.available_to_allocate ?: (expected - allocated)

                    val currencyFormat = currency

                    val categoryList = found.categories?.map { c ->
                        val bSpend = c.budgeted_spending ?: 0.0
                        val aSpend = c.actual_spending ?: 0.0
                        val avail = c.available_to_spend ?: (bSpend - aSpend)
                        val isOver = c.over_budget || (aSpend > bSpend && bSpend > 0)
                        val isNear = c.near_limit

                        val status = when {
                            isOver -> BudgetCategoryStatus.OVER_BUDGET
                            isNear -> BudgetCategoryStatus.NEAR_LIMIT
                            else -> BudgetCategoryStatus.ON_TRACK
                        }

                        val statusText = when (status) {
                            BudgetCategoryStatus.OVER_BUDGET -> "$currencyFormat ${(aSpend - bSpend).toInt()} de más"
                            BudgetCategoryStatus.NEAR_LIMIT -> "$currencyFormat ${avail.toInt()} disponible"
                            BudgetCategoryStatus.ON_TRACK -> "$currencyFormat ${avail.toInt()} disponible"
                        }

                        val dailyUi = c.suggested_daily_spending?.let { d ->
                            SuggestedDailyUiModel(
                                amount = d.amount ?: 0.0,
                                amountCents = d.amount_cents ?: 0L,
                                daysRemaining = d.days_remaining ?: 0
                            )
                        }

                        BudgetCategoryUiModel(
                            id = c.id,
                            budgetId = c.budget_id ?: found.id,
                            categoryId = c.category_id ?: "",
                            name = c.category_name ?: "Categoría",
                            color = c.category_color ?: "#6B7280",
                            icon = c.category_icon,
                            parentId = c.category_parent_id,
                            isSubcategory = c.subcategory,
                            inheritsParentBudget = c.inherits_parent_budget,
                            budgetedSpending = bSpend,
                            budgetedSpendingCents = c.budgeted_spending_cents ?: 0L,
                            actualSpending = aSpend,
                            actualSpendingCents = c.actual_spending_cents ?: 0L,
                            availableToSpend = avail,
                            availableToSpendCents = c.available_to_spend_cents ?: 0L,
                            percentSpent = (c.percent_of_budget_spent ?: c.percent_spent ?: 0.0).toFloat(),
                            barWidthPercent = (c.bar_width_percent ?: 0.0).toFloat(),
                            status = status,
                            statusAmountText = statusText,
                            avgMonthlyExpense = c.avg_monthly_expense ?: 0.0,
                            medianMonthlyExpense = c.median_monthly_expense ?: 0.0,
                            suggestedDailySpending = dailyUi
                        )
                    } ?: emptyList()

                    val categoryGroups = buildCategoryGroups(categoryList)
                    val hasOverBudget = categoryList.any { it.status == BudgetCategoryStatus.OVER_BUDGET }

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
                        budgetId = found.id,
                        budgetName = found.name ?: "",
                        budgetParam = found.param ?: targetPrefix,
                        initialized = found.initialized,
                        isCurrentMonth = found.current,
                        previousBudgetParam = found.previous_budget_param,
                        nextBudgetParam = found.next_budget_param,
                        sourceBudgetId = found.source_budget?.id,
                        sourceBudgetName = found.source_budget?.name,
                        currency = currency,
                        budgetedSpending = budgeted,
                        actualSpending = actual,
                        availableToSpend = available,
                        expectedIncome = expected,
                        actualIncome = found.actual_income ?: 0.0,
                        allocatedSpending = allocated,
                        availableToAllocate = availToAllocate,
                        allocatedPercent = found.allocated_percent ?: 0.0,
                        allocationsValid = found.allocations_valid,
                        percentOfBudgetSpent = found.percent_of_budget_spent ?: 0.0,
                        actualIncomePercent = found.actual_income_percent ?: 0.0,
                        remainingExpectedIncome = found.remaining_expected_income ?: 0.0,
                        surplusPercent = found.surplus_percent ?: 0.0,
                        categories = categoryList,
                        categoryGroups = categoryGroups,
                        hasOverBudgetCategories = hasOverBudget,
                        donutSegments = donutList
                    )
                } else {
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        budgetId = null,
                        budgetName = "",
                        initialized = false,
                        budgetedSpending = 0.0,
                        actualSpending = 0.0,
                        availableToSpend = 0.0,
                        expectedIncome = 0.0,
                        actualIncome = 0.0,
                        allocatedSpending = 0.0,
                        availableToAllocate = 0.0,
                        categories = emptyList(),
                        categoryGroups = emptyList(),
                        hasOverBudgetCategories = false,
                        donutSegments = emptyList()
                    )
                }
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Error al cargar el presupuesto"
                )
            }
        }
    }

    private fun buildCategoryGroups(categories: List<BudgetCategoryUiModel>): List<BudgetCategoryGroupUiModel> {
        val parents = categories.filter { !it.isSubcategory }
        val subcategories = categories.filter { it.isSubcategory }

        return parents.map { parent ->
            val subs = subcategories.filter { it.parentId == parent.categoryId }
            BudgetCategoryGroupUiModel(
                parentCategory = parent,
                subcategories = subs
            )
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
                        label = "Sin asignar",
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
                    label = "Gastado",
                    color = "#3B82F6",
                    amount = actual
                ),
                DonutSegmentUiModel(
                    id = "unused",
                    label = "Disponible",
                    color = "#E5E7EB",
                    amount = (budgeted - actual).coerceAtLeast(0.0)
                )
            )
        }
        return emptyList()
    }
}
