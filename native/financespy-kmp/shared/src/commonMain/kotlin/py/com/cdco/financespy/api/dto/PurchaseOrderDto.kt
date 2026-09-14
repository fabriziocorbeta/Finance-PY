package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class PurchaseOrderItemDto(
    val id: String? = null,
    val purchase_order_id: String? = null,
    val product_id: String,
    val product_name: String? = null,
    val product_sku: String? = null,
    val quantity: Int,
    val unit_cost: Double,
    val subtotal: Double = 0.0,
    val created_at: String? = null,
    val updated_at: String? = null,
    val _destroy: Boolean? = null
)

@Serializable
data class PurchaseOrderDto(
    val id: String,
    val order_number: Int? = null,
    val supplier_name: String? = null,
    val status: String = "draft",
    val currency: String = "pyg",
    val expected_date: String? = null,
    val notes: String? = null,
    val account_id: String? = null,
    val total: Double = 0.0,
    val created_at: String? = null,
    val updated_at: String? = null,
    val purchase_order_items: List<PurchaseOrderItemDto> = emptyList()
)

@Serializable
data class PurchaseOrdersResponseDto(
    val data: List<PurchaseOrderDto> = emptyList()
)

@Serializable
data class PurchaseOrderResponseDto(
    val data: PurchaseOrderDto
)
