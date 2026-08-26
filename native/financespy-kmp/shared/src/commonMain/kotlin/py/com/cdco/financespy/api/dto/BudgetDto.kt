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
data class BudgetDto(
    val id: String,
    val start_date: String? = null,
    val end_date: String? = null,
    val budgeted_spending: String? = null,
    val expected_income: String? = null,
    val currency: String? = null,

    // Additional fields expected when API is upgraded to full dashboard parity
    val actual_spending: Double? = null,
    val available_to_spend: Double? = null,
    val allocated_spending: Double? = null,
    val categories: List<BudgetCategoryDto>? = null,
    val donut_segments: List<BudgetDonutSegmentDto>? = null
)

@Serializable
data class BudgetCategoryDto(
    val id: String,
    val category_id: String? = null,
    val category_name: String? = null,
    val category_color: String? = null,
    val budgeted_spending: Double? = null,
    val actual_spending: Double? = null,
    val available_to_spend: Double? = null,
    val percent_spent: Double? = null
)

@Serializable
data class BudgetDonutSegmentDto(
    val id: String,
    val color: String,
    val amount: Double
)
