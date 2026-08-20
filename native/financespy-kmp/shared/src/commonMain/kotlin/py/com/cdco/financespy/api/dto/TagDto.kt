package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class TagDto(
    val id: String,
    val name: String,
    val color: String
)
