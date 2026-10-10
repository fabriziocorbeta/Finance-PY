import Foundation

// MARK: - DTOs

struct BudgetDto: Codable {
    let id: String
    let startDate: String?
    let endDate: String?
    let currency: String?
    let budgetedSpending: Double?
    let expectedIncome: Double?
    let name: String?
    let param: String?
    let initialized: Bool
    let current: Bool
    let previousBudgetParam: String?
    let nextBudgetParam: String?
    let allocationsValid: Bool
    let actualSpending: Double?
    let actualSpendingCents: Int64?
    let availableToSpend: Double?
    let availableToSpendCents: Int64?
    let allocatedSpending: Double?
    let allocatedSpendingCents: Int64?
    let allocatedPercent: Double?
    let availableToAllocate: Double?
    let availableToAllocateCents: Int64?
    let percentOfBudgetSpent: Double?
    let actualIncome: Double?
    let actualIncomeCents: Int64?
    let actualIncomePercent: Double?
    let remainingExpectedIncome: Double?
    let remainingExpectedIncomeCents: Int64?
    let surplusPercent: Double?
    let donutSegments: [DonutSegmentDto]?
    let sourceBudget: SourceBudgetDto?
    let categories: [BudgetCategoryDto]?
}

struct DonutSegmentDto: Codable, Identifiable {
    let id: String
    let label: String
    let color: String
    let amount: Double
}

struct SourceBudgetDto: Codable {
    let id: String
    let name: String
}

struct BudgetCategoryDto: Codable, Identifiable {
    let id: String
    let budgetId: String?
    let categoryId: String?
    let categoryName: String?
    let categoryColor: String?
    let categoryIcon: String?
    let categoryParentId: String?
    let subcategory: Bool
    let inheritsParentBudget: Bool
    let budgetedSpending: Double?
    let budgetedSpendingCents: Int64?
    let actualSpending: Double?
    let actualSpendingCents: Int64?
    let availableToSpend: Double?
    let availableToSpendCents: Int64?
    let avgMonthlyExpense: Double?
    let avgMonthlyExpenseCents: Int64?
    let medianMonthlyExpense: Double?
    let medianMonthlyExpenseCents: Int64?
    let percentOfBudgetSpent: Double?
    let barWidthPercent: Double?
    let overBudget: Bool
    let nearLimit: Bool
    let budgeted: Bool
    let suggestedDailySpending: SuggestedDailySpendingDto?
}

struct SuggestedDailySpendingDto: Codable {
    let amount: Double?
    let amountCents: Int64?
    let daysRemaining: Int?
}

struct BudgetListResponse: Codable {
    let budgets: [BudgetDto]
    let pagination: PaginationDto
}

struct CreateBudgetRequest: Codable {
    struct BudgetData: Codable {
        let expectedIncome: Double?
        let startDate: String?
        let endDate: String?
    }
    let budget: BudgetData
}

struct UpdateBudgetRequest: Codable {
    struct BudgetData: Codable {
        let expectedIncome: Double?
        let startDate: String?
        let endDate: String?
    }
    let budget: BudgetData
}

struct UpdateBudgetCategoryRequest: Codable {
    struct BudgetCategoryData: Codable {
        let budgetedSpending: Double
    }
    let budgetCategory: BudgetCategoryData
}

// MARK: - API Extension

extension FinancePyApi {
    func fetchBudgets(page: Int = 1, perPage: Int = 25) async throws -> BudgetListResponse {
        let queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]
        return try await ApiClient.shared.request(path: "/api/v1/budgets", queryItems: queryItems)
    }

    func fetchBudget(id: String) async throws -> BudgetDto {
        return try await ApiClient.shared.request(path: "/api/v1/budgets/\(id)")
    }

    func createBudget(expectedIncome: Double?, startDate: String?, endDate: String?) async throws -> BudgetDto {
        let body = CreateBudgetRequest(budget: CreateBudgetRequest.BudgetData(
            expectedIncome: expectedIncome,
            startDate: startDate,
            endDate: endDate
        ))
        return try await ApiClient.shared.request(method: "POST", path: "/api/v1/budgets", body: body)
    }

    func updateBudget(id: String, expectedIncome: Double?) async throws -> BudgetDto {
        let body = UpdateBudgetRequest(budget: UpdateBudgetRequest.BudgetData(
            expectedIncome: expectedIncome,
            startDate: nil,
            endDate: nil
        ))
        return try await ApiClient.shared.request(method: "PUT", path: "/api/v1/budgets/\(id)", body: body)
    }

    func deleteBudget(id: String) async throws -> EmptyResponse {
        return try await ApiClient.shared.request(method: "DELETE", path: "/api/v1/budgets/\(id)")
    }

    func updateBudgetCategory(budgetId: String, categoryId: String, budgetedSpending: Double) async throws -> BudgetCategoryDto {
        let body = UpdateBudgetCategoryRequest(budgetCategory: UpdateBudgetCategoryRequest.BudgetCategoryData(
            budgetedSpending: budgetedSpending
        ))
        return try await ApiClient.shared.request(method: "PUT", path: "/api/v1/budgets/\(budgetId)/budget_categories/\(categoryId)", body: body)
    }
}
