package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class UserDto(
    val id: String,
    val email: String,
    val first_name: String? = null,
    val last_name: String? = null,
    val display_name: String? = null,
    val role: String,
    val theme: String? = null,
    val goals: List<String>? = emptyList(),
    val onboarded_at: String? = null,
    val needs_onboarding: Boolean = false,
    val is_invited: Boolean = false
)

@Serializable
data class NavPreferencesDto(
    val nav_item_order: List<String>? = null
)
