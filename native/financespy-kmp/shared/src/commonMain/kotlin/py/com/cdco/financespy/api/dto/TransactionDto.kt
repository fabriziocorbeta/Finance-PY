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

@Serializable
data class TagRefDto(val id: String, val name: String, val color: String)

@Serializable
data class TransferInfoDto(
    val id: String,
    val amount: String? = null,
    val currency: String? = null,
    val other_account: AccountRefDto? = null
)

@Serializable
data class TransactionDetailDto(
    val id: String,
    val date: String,
    val amount: String,
    val amount_cents: Long,
    val signed_amount_cents: Long,
    val currency: String,
    val name: String,
    val notes: String? = null,
    val classification: String,
    val account: AccountRefDto,
    val category: CategoryRefDto? = null,
    val merchant: MerchantRefDto? = null,
    val tags: List<TagRefDto> = emptyList(),
    val transfer: TransferInfoDto? = null,
    val created_at: String,
    val updated_at: String
)

@Serializable
data class CreateTransactionRequest(
    val transaction: CreateTransactionBody
)

@Serializable
data class CreateTransactionBody(
    val account_id: String,
    val date: String,
    val amount: String,
    val nature: String,
    val name: String,
    val notes: String? = null,
    val currency: String? = null,
    val category_id: String? = null,
    val merchant_id: String? = null,
    val tag_ids: List<String>? = null
)

@Serializable
data class UpdateTransactionRequest(
    val transaction: UpdateTransactionBody
)

@Serializable
data class UpdateTransactionBody(
    val account_id: String? = null,
    val date: String? = null,
    val amount: String? = null,
    val nature: String? = null,
    val name: String? = null,
    val notes: String? = null,
    val currency: String? = null,
    val category_id: String? = null,
    val merchant_id: String? = null,
    val tag_ids: List<String>? = null
)
