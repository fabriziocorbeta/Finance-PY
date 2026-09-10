package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class DashboardDto(
    val greeting_name: String? = null,
    val currency: String = "PYG",
    val period: PeriodDto? = null,
    val net_worth: NetWorthDto? = null,
    val cashflow_sankey: CashflowSankeyDto? = null,
    val outflows_donut: OutflowsDonutDto? = null,
    val balance_sheet: DashboardBalanceSheetDto? = null,
    val investment_summary: InvestmentSummaryDto? = null
)

@Serializable
data class PeriodDto(
    val key: String,
    val label: String
)

@Serializable
data class NetWorthDto(
    val amount: Double = 0.0,
    val amount_cents: Long? = null,
    val currency: String = "PYG",
    val series: List<NetWorthSeriesPointDto> = emptyList(),
    val trend: TrendDto? = null
)

@Serializable
data class NetWorthSeriesPointDto(
    val date: String,
    val date_formatted: String,
    val value: Double
)

@Serializable
data class TrendDto(
    val value: Double = 0.0,
    val percent: Double? = null,
    val percent_formatted: String? = null,
    val direction: String? = null,
    val color: String? = null
)

@Serializable
data class CashflowSankeyDto(
    val currency_symbol: String? = null,
    val nodes: List<SankeyNodeDto> = emptyList(),
    val links: List<SankeyLinkDto> = emptyList()
)

@Serializable
data class SankeyNodeDto(
    val name: String,
    val value: Double = 0.0,
    val percentage: Double? = null,
    val color: String? = null
)

@Serializable
data class SankeyLinkDto(
    val source: Int,
    val target: Int,
    val value: Double = 0.0,
    val color: String? = null,
    val percentage: Double? = null
)

@Serializable
data class OutflowsDonutDto(
    val currency: String = "PYG",
    val currency_symbol: String? = null,
    val total: Double = 0.0,
    val categories: List<DonutCategoryDto> = emptyList()
)

@Serializable
data class DonutCategoryDto(
    val id: String? = null,
    val name: String,
    val amount: Double = 0.0,
    val currency: String? = null,
    val percentage: Double? = null,
    val color: String? = null,
    val icon: String? = null,
    val clickable: Boolean = false
)

@Serializable
data class DashboardBalanceSheetDto(
    val classification_groups: List<ClassificationGroupDto> = emptyList()
)

@Serializable
data class ClassificationGroupDto(
    val classification: String,
    val name: String,
    val icon: String? = null,
    val total: Double = 0.0,
    val total_cents: Long? = null,
    val account_groups: List<AccountGroupDto> = emptyList()
)

@Serializable
data class AccountGroupDto(
    val key: String,
    val name: String,
    val color: String? = null,
    val weight: Double = 0.0,
    val total: Double = 0.0,
    val total_cents: Long? = null,
    val accounts: List<AccountItemDto> = emptyList()
)

@Serializable
data class AccountItemDto(
    val id: String,
    val name: String,
    val balance: Double = 0.0,
    val balance_cents: Long? = null,
    val currency: String = "PYG"
)

@Serializable
data class InvestmentSummaryDto(
    val portfolio_value: Double = 0.0,
    val portfolio_value_cents: Long? = null,
    val currency: String = "PYG",
    val unrealized_gains: UnrealizedGainsDto? = null,
    val top_holdings: List<HoldingDto> = emptyList(),
    val activity: InvestmentActivityDto? = null
)

@Serializable
data class UnrealizedGainsDto(
    val value: Double = 0.0,
    val percent_formatted: String? = null,
    val color: String? = null
)

@Serializable
data class HoldingDto(
    val ticker: String,
    val name: String,
    val logo_url: String? = null,
    val weight: Double = 0.0,
    val value: Double = 0.0,
    val value_cents: Long? = null,
    val return_percent_formatted: String? = null,
    val return_color: String? = null
)

@Serializable
data class InvestmentActivityDto(
    val contributions: Double = 0.0,
    val withdrawals: Double = 0.0,
    val trades_count: Int = 0
)
