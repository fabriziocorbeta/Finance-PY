package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class GoalsEnvelope(
    val data: List<GoalDto>,
    val meta: GoalsMetaDto
)

@Serializable
data class GoalEnvelope(
    val data: GoalDto
)

@Serializable
data class GoalsMetaDto(
    val current_page: Int,
    val next_page: Int? = null,
    val prev_page: Int? = null,
    val total_pages: Int,
    val total_count: Int,
    val per_page: Int
)

@Serializable
data class GoalDto(
    val id: String,
    val name: String,
    val target_amount: String? = null,
    val currency: String? = null,
    val target_date: String? = null,
    val color: String? = null,
    val icon: String? = null,
    val notes: String? = null,
    val state: String? = null,
    val progress_basis: String? = null,
    val current_balance: Double? = null,
    val current_balance_cents: Long? = null,
    val remaining_amount: Double? = null,
    val remaining_amount_cents: Long? = null,
    val progress_percent: Int? = null,
    val account_ids: List<String>? = null,
    val pace: Double? = null,
    val status: String? = null,
    val months_remaining: Double? = null,
    val catch_up_delta: Double? = null,
    val allocations: Map<String, String>? = null
)

@Serializable
data class CreateGoalRequest(
    val goal: CreateGoalBody
)

@Serializable
data class GoalAccountAttributeDto(
    val account_id: String,
    val allocated_amount: String? = null
)

@Serializable
data class CreateGoalBody(
    val name: String,
    val target_amount: String,
    val currency: String? = null,
    val target_date: String? = null,
    val color: String? = null,
    val icon: String? = null,
    val notes: String? = null,
    val progress_basis: String? = null,
    val state: String? = null,
    val account_ids: List<String>,
    val allocations: Map<String, String>? = null,
    val goal_accounts_attributes: List<GoalAccountAttributeDto>? = null
)

@Serializable
data class UpdateGoalRequest(
    val goal: UpdateGoalBody
)

@Serializable
data class UpdateGoalBody(
    val name: String? = null,
    val target_amount: String? = null,
    val currency: String? = null,
    val target_date: String? = null,
    val color: String? = null,
    val icon: String? = null,
    val notes: String? = null,
    val progress_basis: String? = null,
    val state: String? = null,
    val account_ids: List<String>? = null,
    val allocations: Map<String, String>? = null,
    val goal_accounts_attributes: List<GoalAccountAttributeDto>? = null
)
