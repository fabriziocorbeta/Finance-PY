package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.ActionAttributes
import py.com.cdco.financespy.api.dto.CategoryDto
import py.com.cdco.financespy.api.dto.ConditionAttributes
import py.com.cdco.financespy.api.dto.CreateRuleBody
import py.com.cdco.financespy.api.dto.MerchantDto
import py.com.cdco.financespy.api.dto.TagDto
import py.com.cdco.financespy.api.dto.UpdateRuleBody
import py.com.cdco.financespy.db.RuleDao

data class RuleFormState(
    val isEditing: Boolean = false,
    val name: String = "",
    val conditionType: String = "transaction_name",
    val conditionOperator: String = "like",
    val conditionValue: String = "",
    val actionType: String = "set_transaction_category",
    val actionValue: String = "",
    val categories: List<CategoryDto> = emptyList(),
    val merchants: List<MerchantDto> = emptyList(),
    val tags: List<TagDto> = emptyList(),
    val isSaving: Boolean = false,
    val error: String? = null
)

class RuleFormViewModel(
    private val scope: CoroutineScope,
    private val ruleId: String?,
    private val api: FinancePyApi,
    private val ruleDao: RuleDao
) {
    private val _state = MutableStateFlow(RuleFormState(isEditing = ruleId != null))
    val state: StateFlow<RuleFormState> = _state

    init {
        scope.launch {
            val categories = runCatching { api.fetchCategories() }.getOrDefault(emptyList())
            val merchants = runCatching { api.fetchMerchants() }.getOrDefault(emptyList())
            val tags = runCatching { api.fetchTags() }.getOrDefault(emptyList())
            _state.value = _state.value.copy(categories = categories, merchants = merchants, tags = tags)

            if (ruleId != null) {
                ruleDao.findById(ruleId)?.let { rule ->
                    _state.value = _state.value.copy(
                        name = rule.name.orEmpty(),
                        conditionType = rule.conditionType,
                        conditionOperator = rule.conditionOperator,
                        conditionValue = rule.conditionValue,
                        actionType = rule.actionType,
                        actionValue = rule.actionValue
                    )
                }
            }
        }
    }

    fun updateName(value: String) { _state.value = _state.value.copy(name = value) }
    fun updateConditionType(value: String) { _state.value = _state.value.copy(conditionType = value) }
    fun updateConditionOperator(value: String) { _state.value = _state.value.copy(conditionOperator = value) }
    fun updateConditionValue(value: String) { _state.value = _state.value.copy(conditionValue = value) }
    fun updateActionType(value: String) { _state.value = _state.value.copy(actionType = value) }
    fun updateActionValue(value: String) { _state.value = _state.value.copy(actionValue = value) }

    fun save(onSaved: () -> Unit) {
        val s = _state.value
        if (s.conditionValue.isBlank() || s.actionValue.isBlank()) {
            _state.value = s.copy(error = "Completá la condición y la acción antes de guardar")
            return
        }
        scope.launch {
            _state.value = s.copy(isSaving = true, error = null)
            val body = CreateRuleBody(
                name = s.name.ifBlank { null },
                conditions_attributes = listOf(ConditionAttributes(s.conditionType, s.conditionOperator, s.conditionValue)),
                actions_attributes = listOf(ActionAttributes(s.actionType, s.actionValue))
            )
            val result = if (ruleId != null) {
                runCatching { api.updateRule(ruleId, UpdateRuleBody(name = body.name)) }
            } else {
                runCatching { api.createRule(body) }
            }
            result
                .onSuccess { onSaved() }
                .onFailure { e -> _state.value = _state.value.copy(isSaving = false, error = e.message ?: "Error al guardar") }
        }
    }
}
