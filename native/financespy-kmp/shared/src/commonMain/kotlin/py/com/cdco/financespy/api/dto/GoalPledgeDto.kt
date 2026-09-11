package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class GoalPledgeDto(
    val id: String,
    val goal_id: String,
    val account_id: String,
    val amount: Double,
    val currency: String,
    val kind: String,
    val status: String,
    val expires_at: String,
    val days_left: Int,
    val account_name: String
)

@Serializable
data class GoalPledgesEnvelope(
    val data: List<GoalPledgeDto>,
    val meta: GoalPledgesMetaDto? = null
)

@Serializable
data class GoalPledgeEnvelope(
    val data: GoalPledgeDto
)

@Serializable
data class GoalPledgesMetaDto(
    val current_page: Int,
    val next_page: Int? = null,
    val prev_page: Int? = null,
    val total_pages: Int,
    val total_count: Int,
    val per_page: Int
)

@Serializable
data class CreateGoalPledgeRequest(
    val pledge: CreateGoalPledgeBody
)

@Serializable
data class CreateGoalPledgeBody(
    val amount: Double,
    val account_id: String
)
