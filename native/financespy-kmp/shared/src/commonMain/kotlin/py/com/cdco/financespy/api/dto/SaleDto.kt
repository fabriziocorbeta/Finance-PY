package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class SaleItemDto(
    val id: String? = null,
    val sale_id: String? = null,
    val product_id: String,
    val product_name: String? = null,
    val product_sku: String? = null,
    val quantity: Int,
    val unit_price: Double,
    val subtotal: Double = 0.0,
    val created_at: String? = null,
    val updated_at: String? = null,
    val _destroy: Boolean? = null
)

@Serializable
data class SaleDto(
    val id: String,
    val sale_number: Int? = null,
    val client_name: String? = null,
    val status: String = "draft",
    val currency: String = "pyg",
    val payment_method: String? = null,
    val invoice_number: String? = null,
    val condition: String? = null,
    val notes: String? = null,
    val delivery_address: String? = null,
    val delivery_date: String? = null,
    val carrier: String? = null,
    val account_id: String? = null,
    val total: Double = 0.0,
    val created_at: String? = null,
    val updated_at: String? = null,
    val sale_items: List<SaleItemDto> = emptyList()
)

@Serializable
data class SalesResponseDto(
    val data: List<SaleDto> = emptyList()
)

@Serializable
data class SaleResponseDto(
    val data: SaleDto
)
