package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class TransactionsResponse(val transactions: List<TransactionListItemDto>, val pagination: PaginationDto)

@Serializable
data class TransactionListItemDto(
    val id: String,
    val date: String,
    val amount_cents: Long,
    val signed_amount_cents: Long,
    val currency: String,
    val name: String,
    val classification: String,
    val account: AccountRefDto,
    val category: CategoryRefDto? = null,
    val merchant: MerchantRefDto? = null,
    val created_at: String,
    val updated_at: String
)

@Serializable
data class AccountRefDto(val id: String, val name: String, val account_type: String)

@Serializable
data class CategoryRefDto(val id: String, val name: String, val color: String, val icon: String)

@Serializable
data class MerchantRefDto(val id: String, val name: String)
