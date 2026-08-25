package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class ReceivablesEnvelope(
    val data: List<ReceivableDto>,
    val meta: ReceivablesMetaDto? = null
)

@Serializable
data class ReceivableEnvelope(
    val data: ReceivableDto
)

@Serializable
data class ReceivablesMetaDto(
    val current_page: Int,
    val next_page: Int? = null,
    val prev_page: Int? = null,
    val total_pages: Int,
    val total_count: Int,
    val per_page: Int
)

@Serializable
data class ReceivableDto(
    val id: String,
    val name: String? = null,
    val total_amount: Double? = null,
    val balance: Double? = null,
    val balance_cents: Long? = null,
    val original_balance: Double? = null,
    val original_balance_cents: Long? = null,
    val paid_amount: Double? = null,
    val paid_amount_cents: Long? = null,
    val percent_paid: Double? = null,
    val installment_count: Int? = null,
    val due_day: Int? = null,
    val currency: String? = null,
    val notes: String? = null,
    val updated_at: String? = null
)

@Serializable
data class CreateReceivableRequest(
    val receivable: CreateReceivableBody
)

@Serializable
data class CreateReceivableBody(
    val name: String,
    val total_amount: Double,
    val balance: Double? = null,
    val installment_count: Int? = null,
    val due_day: Int? = null,
    val currency: String,
    val notes: String? = null
)

@Serializable
data class UpdateReceivableRequest(
    val receivable: UpdateReceivableBody
)

@Serializable
data class UpdateReceivableBody(
    val name: String? = null,
    val total_amount: Double? = null,
    val balance: Double? = null,
    val installment_count: Int? = null,
    val due_day: Int? = null,
    val currency: String? = null,
    val notes: String? = null
)
