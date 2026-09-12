package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class UserDto(
    val id: String,
    val email: String,
    val first_name: String? = null,
    val last_name: String? = null,
    val display_name: String? = null,
    val role: String
)
