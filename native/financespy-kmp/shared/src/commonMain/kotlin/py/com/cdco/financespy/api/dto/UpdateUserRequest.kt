package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class UpdateFamilyAttributesDto(
    val moniker: String? = null,
    val name: String? = null,
    val country: String? = null,
    val currency: String? = null,
    val locale: String? = null,
    val date_format: String? = null
)

@Serializable
data class UpdateUserBody(
    val first_name: String? = null,
    val last_name: String? = null,
    val theme: String? = null,
    val locale: String? = null,
    val goals: List<String>? = null,
    val set_onboarding_preferences_at: String? = null,
    val set_onboarding_goals_at: String? = null,
    val onboarded_at: String? = null,
    val family_attributes: UpdateFamilyAttributesDto? = null
)

@Serializable
data class UpdateUserRequest(
    val user: UpdateUserBody
)
