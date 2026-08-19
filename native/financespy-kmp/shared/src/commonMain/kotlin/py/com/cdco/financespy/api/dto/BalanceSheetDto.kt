package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class BalanceSheetResponse(
    val currency: String,
    val net_worth: MoneyDto,
    val assets: MoneyDto,
    val liabilities: MoneyDto
)

@Serializable
data class MoneyDto(val cents: Long? = null, val amount: String? = null, val currency: String? = null)
