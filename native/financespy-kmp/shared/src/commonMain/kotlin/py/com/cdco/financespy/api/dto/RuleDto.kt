package py.com.cdco.financespy.api.dto

import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.ExperimentalSerializationApi
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
    val value: String? = null,
    val sub_conditions: List<RuleConditionDto> = emptyList()
)

@Serializable
data class RuleActionDto(
    val id: String,
    val action_type: String,
    val value: String? = null
)

@Serializable
data class RuleFilterDto(
    val type: String,
    val key: String,
    val label: String,
    val operators: List<List<String>>? = null,
    val options: List<List<String>>? = null,
    val number_step: Double? = null
)

@Serializable
data class RuleExecutorDto(
    val type: String,
    val key: String,
    val label: String,
    val options: List<List<String>>? = null
)

@Serializable
data class RuleRegistryDto(
    val filters: List<RuleFilterDto>,
    val executors: List<RuleExecutorDto>
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

@OptIn(ExperimentalSerializationApi::class)
@Serializable
data class CreateRuleBody(
    val name: String?,
    @EncodeDefault val resource_type: String = "transaction",
    @EncodeDefault val active: Boolean = true,
    val effective_date: String? = null,
    val conditions_attributes: List<ConditionAttributes>,
    val actions_attributes: List<ActionAttributes>
)

@Serializable
data class ConditionAttributes(
    val condition_type: String,
    val operator: String,
    val value: String? = null,
    val sub_conditions_attributes: List<ConditionAttributes>? = null
)

@Serializable
data class ActionAttributes(
    val action_type: String,
    val value: String,
    val id: String? = null,
    val _destroy: Boolean? = null
)

@Serializable
data class UpdateRuleRequest(val rule: UpdateRuleBody)

@Serializable
data class UpdateRuleBody(
    val name: String? = null,
    val active: Boolean? = null,
    val effective_date: String? = null,
    val conditions_attributes: List<ConditionAttributes>? = null,
    val actions_attributes: List<ActionAttributes>? = null
)
