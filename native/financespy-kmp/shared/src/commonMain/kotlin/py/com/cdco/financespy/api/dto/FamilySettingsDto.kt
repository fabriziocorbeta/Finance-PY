package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class FamilySettingsDto(
    val id: String,
    val name: String? = null,
    val currency: String,
    val locale: String,
    val date_format: String,
    val country: String? = null,
    val timezone: String? = null,
    val month_start_day: Int,
    val moniker: String? = null,
    val default_account_sharing: String? = null,
    val custom_enabled_currencies: Boolean = false,
    val enabled_currencies: List<String> = emptyList(),
    val created_at: String,
    val updated_at: String,
    val current_user: UserDto? = null,
    val users: List<UserDto> = emptyList()
)
