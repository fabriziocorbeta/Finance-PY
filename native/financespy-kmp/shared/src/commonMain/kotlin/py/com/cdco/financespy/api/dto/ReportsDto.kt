package py.com.cdco.financespy.api.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ReportsSummaryDto(
    val period: ReportPeriodDto,
    val currency: String? = null,
    val summary: ReportSummaryMetricsDto,
    val trends: List<ReportTrendItemDto> = emptyList(),
    @SerialName("cashflow_projections") val cashflowProjections: CashflowProjectionsDto? = null,
    @SerialName("net_worth") val netWorth: ReportNetWorthDto,
    @SerialName("transactions_breakdown") val transactionsBreakdown: ReportTransactionsBreakdownDto,
    @SerialName("investment_metrics") val investmentMetrics: ReportInvestmentMetricsDto? = null,
    @SerialName("investment_flows") val investmentFlows: ReportInvestmentFlowsDto? = null
)

@Serializable
data class ReportPeriodDto(
    @SerialName("start_date") val startDate: String,
    @SerialName("end_date") val endDate: String,
    val type: String
)

@Serializable
data class ReportSummaryMetricsDto(
    val income: Double,
    @SerialName("income_change_pct") val incomeChangePct: Double,
    val expense: Double,
    @SerialName("expense_change_pct") val expenseChangePct: Double,
    @SerialName("net_savings") val netSavings: Double,
    @SerialName("budget_used_pct") val budgetUsedPct: Double? = null
)

@Serializable
data class ReportTrendItemDto(
    val month: String,
    @SerialName("month_name") val monthName: String? = null,
    @SerialName("is_current_month") val isCurrentMonth: Boolean = false,
    val income: Double,
    val expense: Double,
    val net: Double
)

@Serializable
data class ReportNetWorthDto(
    val current: Double,
    @SerialName("total_assets") val totalAssets: Double,
    @SerialName("total_liabilities") val totalLiabilities: Double,
    val change: Double? = null,
    @SerialName("change_pct") val changePct: Double? = null
)

@Serializable
data class ReportTransactionsBreakdownDto(
    val income: List<ReportCategoryBreakdownDto> = emptyList(),
    val expense: List<ReportCategoryBreakdownDto> = emptyList()
)

@Serializable
data class ReportCategoryBreakdownDto(
    @SerialName("category_id") val categoryId: String,
    @SerialName("category_name") val categoryName: String,
    @SerialName("category_color") val categoryColor: String? = null,
    @SerialName("category_icon") val categoryIcon: String? = null,
    val total: Double,
    val count: Int = 0,
    val subcategories: List<ReportSubcategoryBreakdownDto> = emptyList()
)

@Serializable
data class ReportSubcategoryBreakdownDto(
    @SerialName("category_id") val categoryId: String,
    @SerialName("category_name") val categoryName: String,
    @SerialName("category_color") val categoryColor: String? = null,
    @SerialName("category_icon") val categoryIcon: String? = null,
    val total: Double,
    val count: Int = 0
)

@Serializable
data class ReportInvestmentMetricsDto(
    @SerialName("has_investments") val hasInvestments: Boolean = false,
    @SerialName("portfolio_value") val portfolioValue: Double = 0.0,
    @SerialName("unrealized_gain") val unrealizedGain: Double = 0.0,
    @SerialName("unrealized_gain_pct") val unrealizedGainPct: Double? = null,
    @SerialName("period_contributions") val periodContributions: Double = 0.0,
    @SerialName("period_withdrawals") val periodWithdrawals: Double = 0.0,
    @SerialName("top_holdings") val topHoldings: List<ReportTopHoldingDto> = emptyList()
)

@Serializable
data class ReportTopHoldingDto(
    val ticker: String,
    val name: String,
    val weight: Double = 0.0,
    val amount: Double = 0.0,
    @SerialName("return_pct") val returnPct: Double? = null
)

@Serializable
data class ReportInvestmentFlowsDto(
    val contributions: Double = 0.0,
    val withdrawals: Double = 0.0,
    @SerialName("net_flow") val netFlow: Double = 0.0
)

@Serializable
data class CashflowProjectionsDto(
    val currency: String,
    @SerialName("currency_symbol") val currencySymbol: String? = null,
    @SerialName("horizon_months") val horizonMonths: Int,
    @SerialName("historical_series") val historicalSeries: List<CashflowMonthDto> = emptyList(),
    @SerialName("projected_series") val projectedSeries: List<CashflowMonthDto> = emptyList(),
    val drivers: CashflowDriversDto? = null,
    val summary: CashflowProjectionsSummaryDto? = null
)

@Serializable
data class CashflowMonthDto(
    val month: String,
    @SerialName("month_label") val monthLabel: String? = null,
    val date: String? = null,
    val kind: String,
    @SerialName("is_current_month") val isCurrentMonth: Boolean = false,
    val income: Double,
    val expenses: Double,
    val net: Double,
    @SerialName("savings_rate") val savingsRate: Double? = null,
    @SerialName("recurring_income") val recurringIncome: Double? = null,
    @SerialName("recurring_expenses") val recurringExpenses: Double? = null,
    @SerialName("receivables_income") val receivablesIncome: Double? = null,
    val optimistic: CashflowScenarioDto? = null,
    val conservative: CashflowScenarioDto? = null
)

@Serializable
data class CashflowScenarioDto(
    val income: Double,
    val expenses: Double,
    val net: Double
)

@Serializable
data class CashflowRecurringItemDto(
    val name: String,
    val amount: Double,
    val day: Int? = null
)

@Serializable
data class CashflowDriversDto(
    @SerialName("recurring_income_monthly") val recurringIncomeMonthly: Double = 0.0,
    @SerialName("recurring_expenses_monthly") val recurringExpensesMonthly: Double = 0.0,
    @SerialName("recurring_items_count") val recurringItemsCount: Int = 0,
    @SerialName("top_recurring_expenses") val topRecurringExpenses: List<CashflowRecurringItemDto> = emptyList(),
    @SerialName("top_recurring_income") val topRecurringIncome: List<CashflowRecurringItemDto> = emptyList(),
    @SerialName("historical_avg_income") val historicalAvgIncome: Double = 0.0,
    @SerialName("historical_avg_expenses") val historicalAvgExpenses: Double = 0.0,
    @SerialName("has_budget") val hasBudget: Boolean = false,
    @SerialName("scheduled_receivables_total") val scheduledReceivablesTotal: Double = 0.0
)

@Serializable
data class CashflowProjectionsSummaryDto(
    @SerialName("total_projected_income") val totalProjectedIncome: Double = 0.0,
    @SerialName("total_projected_expenses") val totalProjectedExpenses: Double = 0.0,
    @SerialName("total_projected_net") val totalProjectedNet: Double = 0.0,
    @SerialName("avg_monthly_projected_net") val avgMonthlyProjectedNet: Double = 0.0,
    @SerialName("projected_savings_rate") val projectedSavingsRate: Double = 0.0,
    @SerialName("optimistic_total_net") val optimisticTotalNet: Double = 0.0,
    @SerialName("conservative_total_net") val conservativeTotalNet: Double = 0.0
)
