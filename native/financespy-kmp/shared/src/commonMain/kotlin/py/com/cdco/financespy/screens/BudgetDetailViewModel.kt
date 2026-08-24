package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.db.BudgetDao
import py.com.cdco.financespy.db.BudgetEntity

data class BudgetDetailState(
    val budget: BudgetEntity? = null,
    val isDeleting: Boolean = false,
    val deleteError: String? = null
)

class BudgetDetailViewModel(
    private val scope: CoroutineScope,
    private val budgetId: String,
    private val api: FinancePyApi,
    budgetDao: BudgetDao
) {
    private val _state = MutableStateFlow(BudgetDetailState())
    val state: StateFlow<BudgetDetailState> = _state

    init {
        budgetDao.observeAll().onEach { budgets ->
            _state.value = _state.value.copy(budget = budgets.firstOrNull { it.id == budgetId })
        }.launchIn(scope)
    }

    fun delete(onDeleted: () -> Unit) {
        scope.launch {
            _state.value = _state.value.copy(isDeleting = true, deleteError = null)
            runCatching { api.deleteBudget(budgetId) }
                .onSuccess { onDeleted() }
                .onFailure { e ->
                    _state.value = _state.value.copy(isDeleting = false, deleteError = e.message ?: "Error al borrar")
                }
        }
    }
}
