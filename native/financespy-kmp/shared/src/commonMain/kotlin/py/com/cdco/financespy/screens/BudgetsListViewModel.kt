package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import py.com.cdco.financespy.db.BudgetDao
import py.com.cdco.financespy.db.BudgetEntity

class BudgetsListViewModel(
    scope: CoroutineScope,
    budgetDao: BudgetDao
) {
    private val _budgets = MutableStateFlow<List<BudgetEntity>>(emptyList())
    val budgets: StateFlow<List<BudgetEntity>> = _budgets

    init {
        budgetDao.observeAll().onEach { _budgets.value = it }.launchIn(scope)
    }
}
