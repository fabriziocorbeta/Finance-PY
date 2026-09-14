package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class ProductDto(
    val id: String,
    val name: String,
    val sku: String? = null,
    val category: String? = null,
    val supplier: String? = null,
    val buy_price: Double = 0.0,
    val sell_price: Double = 0.0,
    val currency: String = "pyg",
    val stock: Int = 0,
    val min_stock: Int = 0,
    val description: String? = null,
    val created_at: String? = null,
    val updated_at: String? = null
)

@Serializable
data class ProductsResponseDto(
    val data: List<ProductDto> = emptyList()
)

@Serializable
data class ProductResponseDto(
    val data: ProductDto
)
