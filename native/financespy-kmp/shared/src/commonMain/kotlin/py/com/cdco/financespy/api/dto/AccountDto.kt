package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class AccountsResponse(val accounts: List<AccountDto>, val pagination: PaginationDto)

@Serializable
data class AccountDto(
    val id: String,
    val name: String,
    val balance_cents: Long,
    val cash_balance_cents: Long,
    val currency: String,
    val classification: String,
    val account_type: String,
    val subtype: String? = null,
    val status: String,
    val updated_at: String
)

@Serializable
data class PaginationDto(val page: Int, val per_page: Int, val total_count: Int, val total_pages: Int)
