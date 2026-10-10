import Foundation

struct ReportsSummaryDto: Codable {
    let period: ReportPeriodDto
    let currency: String?
    let summary: ReportSummaryMetricsDto
    let trends: [ReportTrendItemDto]
    let netWorth: ReportNetWorthDto
    let transactionsBreakdown: ReportTransactionsBreakdownDto
    let investmentMetrics: ReportInvestmentMetricsDto?
    let investmentFlows: ReportInvestmentFlowsDto?
}

struct ReportPeriodDto: Codable {
    let startDate: String
    let endDate: String
    let type: String
}

struct ReportSummaryMetricsDto: Codable {
    let income: Double
    let incomeChangePct: Double
    let expense: Double
    let expenseChangePct: Double
    let netSavings: Double
    let budgetUsedPct: Double?
}

struct ReportTrendItemDto: Codable {
    let month: String
    let monthName: String?
    let isCurrentMonth: Bool
    let income: Double
    let expense: Double
    let net: Double
}

struct ReportNetWorthDto: Codable {
    let current: Double
    let totalAssets: Double
    let totalLiabilities: Double
    let change: Double?
    let changePct: Double?
}

struct ReportTransactionsBreakdownDto: Codable {
    let income: [ReportCategoryBreakdownDto]
    let expense: [ReportCategoryBreakdownDto]
}

struct ReportCategoryBreakdownDto: Codable, Identifiable {
    let categoryId: String
    let categoryName: String
    let categoryColor: String?
    let categoryIcon: String?
    let total: Double
    let count: Int
    let subcategories: [ReportSubcategoryBreakdownDto]

    var id: String { categoryId }
}

struct ReportSubcategoryBreakdownDto: Codable, Identifiable {
    let categoryId: String
    let categoryName: String
    let categoryColor: String?
    let categoryIcon: String?
    let total: Double
    let count: Int

    var id: String { categoryId }
}

struct ReportInvestmentMetricsDto: Codable {
    let hasInvestments: Bool
    let portfolioValue: Double
    let unrealizedGain: Double
    let unrealizedGainPct: Double?
    let periodContributions: Double
    let periodWithdrawals: Double
    let topHoldings: [ReportTopHoldingDto]
}

struct ReportTopHoldingDto: Codable, Identifiable {
    let ticker: String
    let name: String
    let weight: Double
    let amount: Double
    let returnPct: Double?

    var id: String { ticker }
}

struct ReportInvestmentFlowsDto: Codable {
    let contributions: Double
    let withdrawals: Double
    let netFlow: Double
}
