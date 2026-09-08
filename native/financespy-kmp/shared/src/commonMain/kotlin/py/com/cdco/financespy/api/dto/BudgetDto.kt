package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class BudgetsEnvelope(
    val data: List<BudgetDto>,
    val meta: BudgetsMetaDto? = null
)

@Serializable
data class BudgetEnvelope(
    val data: BudgetDto
)

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
data class BudgetSourceDto(
    val id: String,
    val name: String? = null
)

@Serializable
data class SuggestedDailyDto(
    val amount: Double? = null,
    val amount_cents: Long? = null,
    val days_remaining: Int? = null
)

@Serializable
data class BudgetDto(
    val id: String,
    val name: String? = null,
    val param: String? = null,
    val start_date: String? = null,
    val end_date: String? = null,
    val currency: String? = null,
    val initialized: Boolean = false,
    val current: Boolean = false,
    val previous_budget_param: String? = null,
    val next_budget_param: String? = null,
    val allocations_valid: Boolean = true,
    val budgeted_spending: Double? = null,
    val expected_income: Double? = null,
    val actual_spending: Double? = null,
    val actual_spending_cents: Long? = null,
    val available_to_spend: Double? = null,
    val available_to_spend_cents: Long? = null,
    val allocated_spending: Double? = null,
    val allocated_spending_cents: Long? = null,
    val allocated_percent: Double? = null,
    val available_to_allocate: Double? = null,
    val available_to_allocate_cents: Long? = null,
    val percent_of_budget_spent: Double? = null,
    val actual_income: Double? = null,
    val actual_income_cents: Long? = null,
    val actual_income_percent: Double? = null,
    val remaining_expected_income: Double? = null,
    val remaining_expected_income_cents: Long? = null,
    val surplus_percent: Double? = null,
    val donut_segments: List<BudgetDonutSegmentDto>? = null,
    val source_budget: BudgetSourceDto? = null,
    val categories: List<BudgetCategoryDto>? = null
)

@Serializable
data class BudgetCategoryDto(
    val id: String,
    val budget_id: String? = null,
    val category_id: String? = null,
    val category_name: String? = null,
    val category_color: String? = null,
    val category_icon: String? = null,
    val category_parent_id: String? = null,
    val subcategory: Boolean = false,
    val inherits_parent_budget: Boolean = false,
    val budgeted_spending: Double? = null,
    val budgeted_spending_cents: Long? = null,
    val actual_spending: Double? = null,
    val actual_spending_cents: Long? = null,
    val available_to_spend: Double? = null,
    val available_to_spend_cents: Long? = null,
    val avg_monthly_expense: Double? = null,
    val avg_monthly_expense_cents: Long? = null,
    val median_monthly_expense: Double? = null,
    val median_monthly_expense_cents: Long? = null,
    val percent_of_budget_spent: Double? = null,
    val percent_spent: Double? = null,
    val bar_width_percent: Double? = null,
    val over_budget: Boolean = false,
    val near_limit: Boolean = false,
    val budgeted: Boolean = false,
    val suggested_daily_spending: SuggestedDailyDto? = null
)

@Serializable
data class BudgetDonutSegmentDto(
    val id: String,
    val color: String,
    val amount: Double
)

@Serializable
data class UpdateBudgetCategoryRequest(
    val budget_category: UpdateBudgetCategoryBody
)

@Serializable
data class UpdateBudgetCategoryBody(
    val budgeted_spending: Double? = null
)

@Serializable
data class BudgetCategoryEnvelope(
    val data: BudgetCategoryDto
)

@Serializable
data class UpdateBudgetBody(
    val budgeted_spending: Double? = null,
    val expected_income: Double? = null
)

@Serializable
data class UpdateBudgetRequest(
    val budget: UpdateBudgetBody
)
