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
    val progress_percent: Int? = null
)

@Serializable
data class CreateGoalRequest(
    val goal: CreateGoalBody
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
    val account_ids: List<String>
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
    val account_ids: List<String>? = null
)
