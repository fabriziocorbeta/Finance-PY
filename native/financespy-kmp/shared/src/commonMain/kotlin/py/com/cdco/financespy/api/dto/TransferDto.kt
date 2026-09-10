package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class CreateTransferRequest(val transfer: CreateTransferBody)

@Serializable
data class CreateTransferBody(
    val from_account_id: String,
    val to_account_id: String,
    val amount: Double,
    val date: String
)

@Serializable
data class TransferDto(
    val id: String,
    val status: String,
    val date: String,
    val amount: Double,
    val currency: String,
    val from_account: TransferAccountRefDto,
    val to_account: TransferAccountRefDto
)

@Serializable
data class TransferAccountRefDto(val id: String, val name: String)
