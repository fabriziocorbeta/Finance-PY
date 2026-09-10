package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.ActionAttributes
import py.com.cdco.financespy.api.dto.ConditionAttributes
import py.com.cdco.financespy.api.dto.CreateRuleBody
import py.com.cdco.financespy.api.dto.RuleRegistryDto
import py.com.cdco.financespy.api.dto.UpdateRuleBody

/**
 * A single condition_type/operator/value triple - either a bare top-level condition,
 * or one of the sub-conditions inside a compound (AND/OR) group.
 */
data class LeafCondition(
    val conditionType: String = "",
    val operator: String = "",
    val value: String = ""
)

/**
 * Top-level entry in the "Condiciones" list. The backend (Rule::Condition) represents a
 * compound group as a condition row with condition_type == "compound", whose own `operator`
 * holds "and"/"or" and whose sub_conditions carry the real leaf conditions. Nested compounds
 * are not allowed, so a Group can only ever contain Leaf-shaped sub-conditions.
 */
sealed class ConditionGroupItem {
    data class Leaf(val condition: LeafCondition = LeafCondition()) : ConditionGroupItem()
    data class Group(
        val operator: String = "and",
        val subConditions: List<LeafCondition> = listOf(LeafCondition())
    ) : ConditionGroupItem()
}

/** A single action_type/value pair. Actions are always a flat list, never grouped. */
data class LeafAction(
    val actionType: String = "",
    val value: String = ""
)

data class RuleFormState(
    val isEditing: Boolean = false,
    val isLoading: Boolean = true,
    val isSaving: Boolean = false,
    val error: String? = null,
    val name: String = "",
    val active: Boolean = true,
    val effectiveDateEnabled: Boolean = false,
    val effectiveDate: String = "",
    val registry: RuleRegistryDto? = null,
    val conditionGroups: List<ConditionGroupItem> = listOf(ConditionGroupItem.Leaf()),
    val actions: List<LeafAction> = listOf(LeafAction())
)

class RuleFormViewModel(
    private val scope: CoroutineScope,
    private val ruleId: String?,
    private val api: FinancePyApi
) {
    private val _state = MutableStateFlow(RuleFormState(isEditing = ruleId != null))
    val state: StateFlow<RuleFormState> = _state

    init {
        scope.launch {
            _state.value = _state.value.copy(isLoading = true, error = null)

            val registry = runCatching { api.fetchRuleRegistry() }.getOrNull()
            val loadErrors = mutableListOf<String>()
            if (registry == null) loadErrors += "No se pudo cargar el catálogo de reglas"

            var loadedName = _state.value.name
            var loadedActive = _state.value.active
            var loadedEffectiveDateEnabled = _state.value.effectiveDateEnabled
            var loadedEffectiveDate = _state.value.effectiveDate
            var loadedConditionGroups = _state.value.conditionGroups
            var loadedActions = _state.value.actions

            if (ruleId != null) {
                val existingRule = runCatching { api.fetchAllRules() }
                    .getOrNull()
                    ?.firstOrNull { it.id == ruleId }

                if (existingRule != null) {
                    loadedName = existingRule.name.orEmpty()
                    loadedActive = existingRule.active
                    loadedEffectiveDateEnabled = existingRule.effective_date != null
                    loadedEffectiveDate = existingRule.effective_date.orEmpty()

                    loadedConditionGroups = existingRule.conditions.map { condition ->
                        if (condition.condition_type == "compound") {
                            ConditionGroupItem.Group(
                                operator = condition.operator,
                                subConditions = condition.sub_conditions
                                    .map { LeafCondition(it.condition_type, it.operator, it.value.orEmpty()) }
                                    .ifEmpty { listOf(LeafCondition()) }
                            )
                        } else {
                            ConditionGroupItem.Leaf(
                                LeafCondition(condition.condition_type, condition.operator, condition.value.orEmpty())
                            )
                        }
                    }.ifEmpty { listOf(ConditionGroupItem.Leaf()) }

                    loadedActions = existingRule.actions
                        .map { LeafAction(it.action_type, it.value.orEmpty()) }
                        .ifEmpty { listOf(LeafAction()) }
                } else {
                    loadErrors += "No se pudo cargar la regla"
                }
            }

            _state.value = _state.value.copy(
                isLoading = false,
                registry = registry,
                name = loadedName,
                active = loadedActive,
                effectiveDateEnabled = loadedEffectiveDateEnabled,
                effectiveDate = loadedEffectiveDate,
                conditionGroups = loadedConditionGroups,
                actions = loadedActions,
                error = loadErrors.joinToString(". ").ifBlank { null }
            )
        }
    }

    fun updateName(value: String) {
        _state.value = _state.value.copy(name = value)
    }

    fun updateActive(value: Boolean) {
        _state.value = _state.value.copy(active = value)
    }

    fun updateEffectiveDateEnabled(value: Boolean) {
        _state.value = _state.value.copy(effectiveDateEnabled = value)
    }

    fun updateEffectiveDate(value: String) {
        _state.value = _state.value.copy(effectiveDate = value)
    }

    // ---- Top-level conditions ----

    fun addCondition() {
        _state.value = _state.value.copy(conditionGroups = _state.value.conditionGroups + ConditionGroupItem.Leaf())
    }

    fun addConditionGroup() {
        _state.value = _state.value.copy(conditionGroups = _state.value.conditionGroups + ConditionGroupItem.Group())
    }

    /** Removes a top-level entry - works for both a bare leaf condition and a whole group. */
    fun removeCondition(index: Int) {
        val current = _state.value.conditionGroups
        if (index !in current.indices) return
        val updated = current.toMutableList().apply { removeAt(index) }
        _state.value = _state.value.copy(conditionGroups = updated.ifEmpty { listOf(ConditionGroupItem.Leaf()) })
    }

    /** Updates a top-level leaf condition's field ("condition_type" | "operator" | "value"). */
    fun updateCondition(index: Int, field: String, value: String) {
        val current = _state.value.conditionGroups
        val entry = current.getOrNull(index) as? ConditionGroupItem.Leaf ?: return
        val updated = current.toMutableList().apply {
            this[index] = entry.copy(condition = entry.condition.updateField(field, value))
        }
        _state.value = _state.value.copy(conditionGroups = updated)
    }

    // ---- Compound (AND/OR) group editing ----

    fun updateGroupOperator(groupIndex: Int, operator: String) {
        val current = _state.value.conditionGroups
        val entry = current.getOrNull(groupIndex) as? ConditionGroupItem.Group ?: return
        val updated = current.toMutableList().apply { this[groupIndex] = entry.copy(operator = operator) }
        _state.value = _state.value.copy(conditionGroups = updated)
    }

    fun addSubCondition(groupIndex: Int) {
        val current = _state.value.conditionGroups
        val entry = current.getOrNull(groupIndex) as? ConditionGroupItem.Group ?: return
        val updated = current.toMutableList().apply {
            this[groupIndex] = entry.copy(subConditions = entry.subConditions + LeafCondition())
        }
        _state.value = _state.value.copy(conditionGroups = updated)
    }

    fun removeSubCondition(groupIndex: Int, subIndex: Int) {
        val current = _state.value.conditionGroups
        val entry = current.getOrNull(groupIndex) as? ConditionGroupItem.Group ?: return
        if (subIndex !in entry.subConditions.indices) return
        val updatedSubs = entry.subConditions.toMutableList().apply { removeAt(subIndex) }
        val updated = current.toMutableList().apply {
            this[groupIndex] = entry.copy(subConditions = updatedSubs.ifEmpty { listOf(LeafCondition()) })
        }
        _state.value = _state.value.copy(conditionGroups = updated)
    }

    /** Updates a sub-condition's field ("condition_type" | "operator" | "value") inside a group. */
    fun updateSubCondition(groupIndex: Int, subIndex: Int, field: String, value: String) {
        val current = _state.value.conditionGroups
        val entry = current.getOrNull(groupIndex) as? ConditionGroupItem.Group ?: return
        val sub = entry.subConditions.getOrNull(subIndex) ?: return
        val updatedSubs = entry.subConditions.toMutableList().apply { this[subIndex] = sub.updateField(field, value) }
        val updated = current.toMutableList().apply { this[groupIndex] = entry.copy(subConditions = updatedSubs) }
        _state.value = _state.value.copy(conditionGroups = updated)
    }

    // ---- Actions (flat list) ----

    fun addAction() {
        _state.value = _state.value.copy(actions = _state.value.actions + LeafAction())
    }

    fun removeAction(index: Int) {
        val current = _state.value.actions
        if (index !in current.indices) return
        val updated = current.toMutableList().apply { removeAt(index) }
        _state.value = _state.value.copy(actions = updated.ifEmpty { listOf(LeafAction()) })
    }

    /** Updates an action's field ("action_type" | "value"). Changing action_type clears value. */
    fun updateAction(index: Int, field: String, value: String) {
        val current = _state.value.actions
        val action = current.getOrNull(index) ?: return
        val updatedAction = when (field) {
            "action_type" -> action.copy(actionType = value, value = "")
            "value" -> action.copy(value = value)
            else -> action
        }
        val updated = current.toMutableList().apply { this[index] = updatedAction }
        _state.value = _state.value.copy(actions = updated)
    }

    fun save(onSaved: () -> Unit) {
        val s = _state.value

        val conditionsAttributes = s.conditionGroups.mapNotNull { it.toConditionAttributesOrNull() }
        val actionsAttributes = s.actions
            .filter { it.actionType.isNotBlank() }
            .map { ActionAttributes(action_type = it.actionType, value = it.value) }

        if (conditionsAttributes.isEmpty()) {
            _state.value = s.copy(error = "Agregá al menos una condición")
            return
        }
        if (actionsAttributes.isEmpty()) {
            _state.value = s.copy(error = "Agregá al menos una acción")
            return
        }

        scope.launch {
            _state.value = s.copy(isSaving = true, error = null)
            val effectiveDate = if (s.effectiveDateEnabled) s.effectiveDate.ifBlank { null } else null

            val result = if (ruleId != null) {
                runCatching {
                    api.updateRule(
                        ruleId,
                        UpdateRuleBody(
                            name = s.name.ifBlank { null },
                            active = s.active,
                            effective_date = effectiveDate,
                            conditions_attributes = conditionsAttributes,
                            actions_attributes = actionsAttributes
                        )
                    )
                }
            } else {
                runCatching {
                    api.createRule(
                        CreateRuleBody(
                            name = s.name.ifBlank { null },
                            active = s.active,
                            effective_date = effectiveDate,
                            conditions_attributes = conditionsAttributes,
                            actions_attributes = actionsAttributes
                        )
                    )
                }
            }

            result
                .onSuccess { onSaved() }
                .onFailure { e -> _state.value = _state.value.copy(isSaving = false, error = e.message ?: "Error al guardar") }
        }
    }
}

private fun LeafCondition.updateField(field: String, newValue: String): LeafCondition = when (field) {
    "condition_type" -> copy(conditionType = newValue, operator = "", value = "")
    "operator" -> copy(operator = newValue)
    "value" -> copy(value = newValue)
    else -> this
}

private fun ConditionGroupItem.toConditionAttributesOrNull(): ConditionAttributes? = when (this) {
    is ConditionGroupItem.Leaf -> condition
        .takeIf { it.conditionType.isNotBlank() && it.operator.isNotBlank() }
        ?.let { ConditionAttributes(condition_type = it.conditionType, operator = it.operator, value = it.value.ifBlank { null }) }

    is ConditionGroupItem.Group -> {
        val subs = subConditions
            .filter { it.conditionType.isNotBlank() && it.operator.isNotBlank() }
            .map { ConditionAttributes(condition_type = it.conditionType, operator = it.operator, value = it.value.ifBlank { null }) }

        if (subs.isEmpty()) {
            null
        } else {
            ConditionAttributes(
                condition_type = "compound",
                operator = operator,
                value = null,
                sub_conditions_attributes = subs
            )
        }
    }
}
