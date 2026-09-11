package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class BalanceSeriesPointDto(
    val date: String,
    val balance: Double
)

@Serializable
data class BalanceSeriesTrendDto(
    val start_balance: Double? = null,
    val end_balance: Double? = null,
    val value: Double? = null,
    val percent: Double? = null,
    val percent_formatted: String? = null,
    val direction: String? = null,
    val color: String? = null
)

@Serializable
data class BalanceSeriesDto(
    val currency: String = "PYG",
    val period: String = "last_30_days",
    val series: List<BalanceSeriesPointDto> = emptyList(),
    val trend: BalanceSeriesTrendDto? = null
)
