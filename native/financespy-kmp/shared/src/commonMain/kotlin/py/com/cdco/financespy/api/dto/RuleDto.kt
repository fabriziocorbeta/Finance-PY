package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class RulesEnvelope(val data: List<RuleDto>, val meta: RulesMetaDto)

@Serializable
data class RuleEnvelope(val data: RuleDto)

@Serializable
data class RulesMetaDto(
    val current_page: Int,
    val next_page: Int? = null,
    val prev_page: Int? = null,
    val total_pages: Int,
    val total_count: Int,
    val per_page: Int
)

@Serializable
data class RuleDto(
    val id: String,
    val name: String? = null,
    val resource_type: String,
    val active: Boolean,
    val effective_date: String? = null,
    val conditions: List<RuleConditionDto>,
    val actions: List<RuleActionDto>,
    val created_at: String,
    val updated_at: String
)

@Serializable
data class RuleConditionDto(
    val id: String,
    val condition_type: String,
    val operator: String,
    val value: String? = null
)

@Serializable
data class RuleActionDto(
    val id: String,
    val action_type: String,
    val value: String? = null
)

@Serializable
data class RuleRunsEnvelope(val data: List<RuleRunDto>, val meta: RulesMetaDto)

@Serializable
data class RuleRunDto(
    val id: String,
    val rule_id: String,
    val status: String,
    val execution_type: String,
    val executed_at: String? = null
)

@Serializable
data class CreateRuleRequest(
    val rule: CreateRuleBody
)

@Serializable
data class CreateRuleBody(
    val name: String?,
    val resource_type: String = "transaction",
    val active: Boolean = true,
    val conditions_attributes: List<ConditionAttributes>,
    val actions_attributes: List<ActionAttributes>
)

@Serializable
data class ConditionAttributes(
    val condition_type: String,
    val operator: String,
    val value: String
)

@Serializable
data class ActionAttributes(
    val action_type: String,
    val value: String
)

@Serializable
data class UpdateRuleRequest(val rule: UpdateRuleBody)

@Serializable
data class UpdateRuleBody(val active: Boolean? = null, val name: String? = null)
