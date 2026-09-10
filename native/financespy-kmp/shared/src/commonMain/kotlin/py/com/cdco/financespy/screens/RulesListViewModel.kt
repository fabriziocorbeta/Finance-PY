package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.RuleRegistryDto
import py.com.cdco.financespy.db.RuleDao
import py.com.cdco.financespy.db.RuleEntity

class RulesListViewModel(
    scope: CoroutineScope,
    ruleDao: RuleDao,
    api: FinancePyApi
) {
    private val _rules = MutableStateFlow<List<RuleEntity>>(emptyList())
    val rules: StateFlow<List<RuleEntity>> = _rules

    private val _registry = MutableStateFlow<RuleRegistryDto?>(null)
    val registry: StateFlow<RuleRegistryDto?> = _registry

    init {
        ruleDao.observeAll().onEach { _rules.value = it }.launchIn(scope)
        scope.launch {
            runCatching { api.fetchRuleRegistry() }.onSuccess { _registry.value = it }
        }
    }
}
