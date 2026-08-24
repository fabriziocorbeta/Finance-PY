package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class BudgetsEnvelope(val data: List<BudgetDto>, val meta: BudgetsMetaDto)

@Serializable
data class BudgetEnvelope(val data: BudgetDto)

@Serializable
data class BudgetsMetaDto(
    val current_page: Int,
    val next_page: Int? = null,
    val prev_page: Int? = null,
    val total_pages: Int,
    val total_count: Int,
    val per_page: Int
)

@Serializable
data class BudgetDto(
    val id: String,
    val start_date: String,
    val end_date: String,
    val budgeted_spending: Double = 0.0,
    val expected_income: Double = 0.0,
    val currency: String = "USD",
    val actual_spending: Double = 0.0,
    val actual_spending_cents: Long = 0L,
    val allocated_spending: Double = 0.0,
    val allocated_spending_cents: Long = 0L,
    val available_to_spend: Double = 0.0,
    val available_to_spend_cents: Long = 0L,
    val percent_of_budget_spent: Double = 0.0,
    val actual_income: Double = 0.0,
    val actual_income_cents: Long = 0L,
    val remaining_expected_income: Double = 0.0,
    val remaining_expected_income_cents: Long = 0L
)

@Serializable
data class CreateBudgetRequest(val budget: CreateBudgetBody)

@Serializable
data class CreateBudgetBody(
    val start_date: String,
    val budgeted_spending: Double,
    val expected_income: Double? = null
)

@Serializable
data class UpdateBudgetRequest(val budget: UpdateBudgetBody)

@Serializable
data class UpdateBudgetBody(
    val budgeted_spending: Double? = null,
    val expected_income: Double? = null
)
