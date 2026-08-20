package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import py.com.cdco.financespy.db.RuleDao
import py.com.cdco.financespy.db.RuleEntity

class RulesListViewModel(
    scope: CoroutineScope,
    ruleDao: RuleDao
) {
    private val _rules = MutableStateFlow<List<RuleEntity>>(emptyList())
    val rules: StateFlow<List<RuleEntity>> = _rules

    init {
        ruleDao.observeAll().onEach { _rules.value = it }.launchIn(scope)
    }
}
