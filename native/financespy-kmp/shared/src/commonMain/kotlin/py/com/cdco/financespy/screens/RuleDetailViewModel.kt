package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.UpdateRuleBody
import py.com.cdco.financespy.db.RuleDao
import py.com.cdco.financespy.db.RuleEntity
import py.com.cdco.financespy.db.RuleRunDao
import py.com.cdco.financespy.db.RuleRunEntity

data class RuleDetailState(
    val rule: RuleEntity? = null,
    val runs: List<RuleRunEntity> = emptyList(),
    val isDeleting: Boolean = false,
    val isTogglingActive: Boolean = false,
    val deleteError: String? = null,
    val toggleError: String? = null
)

class RuleDetailViewModel(
    private val scope: CoroutineScope,
    private val ruleId: String,
    private val api: FinancePyApi,
    ruleDao: RuleDao,
    ruleRunDao: RuleRunDao
) {
    private val _state = MutableStateFlow(RuleDetailState())
    val state: StateFlow<RuleDetailState> = _state

    init {
        combine(ruleDao.observeAll(), ruleRunDao.observeByRuleId(ruleId)) { rules, runs ->
            _state.value.copy(rule = rules.firstOrNull { it.id == ruleId }, runs = runs)
        }.onEach { _state.value = it }.launchIn(scope)
    }

    fun toggleActive() {
        val current = _state.value.rule ?: return
        scope.launch {
            _state.value = _state.value.copy(isTogglingActive = true, toggleError = null)
            runCatching {
                api.updateRule(ruleId, UpdateRuleBody(active = !current.active))
            }
                .onSuccess { _state.value = _state.value.copy(isTogglingActive = false) }
                .onFailure { e -> _state.value = _state.value.copy(isTogglingActive = false, toggleError = e.message ?: "Error al cambiar estado") }
        }
    }

    fun delete(onDeleted: () -> Unit) {
        scope.launch {
            _state.value = _state.value.copy(isDeleting = true, deleteError = null)
            runCatching { api.deleteRule(ruleId) }
                .onSuccess { onDeleted() }
                .onFailure { e -> _state.value = _state.value.copy(isDeleting = false, deleteError = e.message ?: "Error al borrar") }
        }
    }
}
