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
    val updated_at: String,
    val has_invoice_photo: Boolean = false,
    val invoice_photo: InvoicePhotoDto? = null,
    // Local-only: a create still waiting in the offline outbox (never sent by the server).
    val pending: Boolean = false
)

@Serializable
data class AccountRefDto(val id: String, val name: String, val account_type: String)

@Serializable
data class CategoryRefDto(val id: String, val name: String, val color: String, val icon: String)

@Serializable
data class MerchantRefDto(val id: String, val name: String)

@Serializable
data class TagRefDto(val id: String, val name: String, val color: String)

// Approximate DEVICE location at the moment a bank notification was
// captured (Wallet capture pipeline) -- never the real merchant location,
// the notification itself never carries coordinates. Only present for
// transactions captured that way.
@Serializable
data class TransactionLocationDto(
    val latitude: Double,
    val longitude: Double,
    val device: String? = null
)

@Serializable
data class TransferInfoDto(
    val id: String,
    val amount: String? = null,
    val currency: String? = null,
    val other_account: AccountRefDto? = null
)

@Serializable
data class TransactionFuelLogLineDto(
    val id: String? = null,
    val fuel_type: String = "nafta",
    val brand: String? = null,
    val liters: Double = 0.0,
    val cost: Double = 0.0
)

@Serializable
data class TransactionFuelLogDto(
    val id: String? = null,
    val fleet_vehicle_id: String,
    val vehicle_plate: String? = null,
    val odometer: Double? = null,
    val notes: String? = null,
    val liters: Double = 0.0,
    val cost: Double = 0.0,
    val fuel_log_lines: List<TransactionFuelLogLineDto> = emptyList()
)

@Serializable
data class TransactionFuelLogLineRequestDto(
    val id: String? = null,
    val fuel_type: String,
    val brand: String? = null,
    val liters: Double,
    val cost: Double,
    val _destroy: Boolean? = null
)

@Serializable
data class TransactionFuelLogRequestDto(
    val fleet_vehicle_id: String,
    val odometer: Double? = null,
    val notes: String? = null,
    val fuel_log_lines_attributes: List<TransactionFuelLogLineRequestDto>
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
    val location: TransactionLocationDto? = null,
    val fuel_log: TransactionFuelLogDto? = null,
    val has_invoice_photo: Boolean = false,
    val invoice_photo: InvoicePhotoDto? = null,
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
    val tag_ids: List<String>? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val fuel_log: TransactionFuelLogRequestDto? = null
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
    val tag_ids: List<String>? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val fuel_log: TransactionFuelLogRequestDto? = null
)
