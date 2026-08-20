package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class MerchantDto(
    val id: String,
    val name: String,
    val type: String
)
