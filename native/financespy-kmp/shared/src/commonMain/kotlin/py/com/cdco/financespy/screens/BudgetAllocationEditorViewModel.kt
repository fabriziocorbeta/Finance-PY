package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.BudgetCategoryDto

data class CategoryAllocationItem(
    val id: String,
    val categoryId: String,
    val categoryName: String,
    val categoryColor: String,
    val categoryIcon: String?,
    val parentId: String?,
    val isSubcategory: Boolean,
    val inheritsParentBudget: Boolean,
    val currentBudgeted: Double,
    val inputValue: String
)

data class AllocationEditorUiState(
    val budgetId: String,
    val budgetName: String = "",
    val currency: String = "USD",
    val expectedIncome: Double = 0.0,
    val totalAllocated: Double = 0.0,
    val availableToAllocate: Double = 0.0,
    val allocatedPercent: Double = 0.0,
    val allocationsValid: Boolean = true,
    val categories: List<CategoryAllocationItem> = emptyList(),
    val inputs: Map<String, String> = emptyMap(), // categoryId -> input string
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val error: String? = null,
    val saveSuccess: Boolean = false
)

class BudgetAllocationEditorViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    private val budgetId: String
) {
    private val _uiState = MutableStateFlow(AllocationEditorUiState(budgetId = budgetId))
    val uiState: StateFlow<AllocationEditorUiState> = _uiState.asStateFlow()

    init {
        loadBudgetData()
    }

    fun loadBudgetData() {
        scope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val budget = api.fetchBudget(budgetId)
                val catList = budget.categories ?: emptyList()
                val inputsMap = mutableMapOf<String, String>()

                val items = catList.map { c ->
                    val valStr = if (c.inherits_parent_budget && (c.budgeted_spending == null || c.budgeted_spending == 0.0)) {
                        ""
                    } else {
                        c.budgeted_spending?.let { if (it == it.toLong().toDouble()) it.toLong().toString() else it.toString() } ?: ""
                    }
                    inputsMap[c.id] = valStr

                    CategoryAllocationItem(
                        id = c.id,
                        categoryId = c.category_id ?: "",
                        categoryName = c.category_name ?: "Categoría",
                        categoryColor = c.category_color ?: "#6B7280",
                        categoryIcon = c.category_icon,
                        parentId = c.category_parent_id,
                        isSubcategory = c.subcategory,
                        inheritsParentBudget = c.inherits_parent_budget,
                        currentBudgeted = c.budgeted_spending ?: 0.0,
                        inputValue = valStr
                    )
                }

                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    budgetName = budget.name ?: "",
                    currency = budget.currency ?: "USD",
                    expectedIncome = budget.expected_income ?: 0.0,
                    totalAllocated = budget.allocated_spending ?: 0.0,
                    availableToAllocate = budget.available_to_allocate ?: 0.0,
                    allocatedPercent = budget.allocated_percent ?: 0.0,
                    allocationsValid = budget.allocations_valid,
                    categories = items,
                    inputs = inputsMap
                )
                recalculateTotals()
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Error al cargar el presupuesto"
                )
            }
        }
    }

    fun onInputChanged(budgetCategoryId: String, newValue: String) {
        val updatedInputs = _uiState.value.inputs.toMutableMap()
        updatedInputs[budgetCategoryId] = newValue
        _uiState.value = _uiState.value.copy(inputs = updatedInputs)
        recalculateTotals()
    }

    private fun recalculateTotals() {
        val currentState = _uiState.value
        val parentCategories = currentState.categories.filter { !it.isSubcategory }
        val subcategories = currentState.categories.filter { it.isSubcategory }

        var total = 0.0
        parentCategories.forEach { parent ->
            val parentInput = currentState.inputs[parent.id]?.toDoubleOrNull()
            val childInputs = subcategories.filter { it.parentId == parent.categoryId }
            var subtotal = 0.0
            childInputs.forEach { child ->
                val childVal = currentState.inputs[child.id]?.toDoubleOrNull()
                if (childVal != null) {
                    subtotal += childVal
                }
            }
            total += (parentInput ?: 0.0) + subtotal
        }

        val income = currentState.expectedIncome
        val available = income - total
        val percent = if (income > 0) (total / income) * 100.0 else 0.0
        val isValid = available >= 0

        _uiState.value = currentState.copy(
            totalAllocated = total,
            availableToAllocate = available,
            allocatedPercent = percent,
            allocationsValid = isValid
        )
    }

    fun saveAllocations() {
        scope.launch {
            _uiState.value = _uiState.value.copy(isSaving = true, error = null)
            try {
                val currentState = _uiState.value
                val categories = currentState.categories

                for (item in categories) {
                    val inputStr = currentState.inputs[item.id]
                    val newDouble = inputStr?.toDoubleOrNull()
                    // Send update if changed or entered value
                    if (inputStr != item.inputValue) {
                        api.updateBudgetCategory(
                            budgetId = budgetId,
                            categoryId = item.id,
                            budgetedSpending = newDouble
                        )
                    }
                }

                _uiState.value = _uiState.value.copy(isSaving = false, saveSuccess = true)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isSaving = false,
                    error = e.message ?: "Error al guardar las asignaciones"
                )
            }
        }
    }
}
