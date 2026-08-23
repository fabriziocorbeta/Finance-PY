import Foundation

// MARK: - DTOs

struct AccountsResponse: Codable {
    let accounts: [AccountDto]
    let pagination: PaginationDto
}

struct AccountDto: Codable {
    let id: String
    let name: String
    let balanceCents: Int64
    let cashBalanceCents: Int64
    let currency: String
    let classification: String
    let accountType: String
    let subtype: String?
    let status: String
    let updatedAt: String
}

struct PaginationDto: Codable {
    let page: Int
    let perPage: Int
    let totalCount: Int
    let totalPages: Int
}

struct BalanceSheetResponse: Codable {
    let currency: String
    let netWorth: MoneyDto
    let assets: MoneyDto
    let liabilities: MoneyDto
}

struct MoneyDto: Codable {
    let cents: Int64?
    let amount: String?
    let currency: String?
}

struct TransactionsResponse: Codable {
    let transactions: [TransactionListItemDto]
    let pagination: PaginationDto
}

struct TransactionListItemDto: Codable {
    let id: String
    let date: String
    let amountCents: Int64
    let signedAmountCents: Int64
    let currency: String
    let name: String
    let classification: String
    let account: AccountRefDto
    let category: CategoryRefDto?
    let merchant: MerchantRefDto?
    let createdAt: String
    let updatedAt: String
}

struct AccountRefDto: Codable {
    let id: String
    let name: String
    let accountType: String
}

struct CategoryRefDto: Codable {
    let id: String
    let name: String
    let color: String
    let icon: String
}

struct MerchantRefDto: Codable {
    let id: String
    let name: String
}

// MARK: - API Service

final class FinancePyApi {
    static let shared = FinancePyApi()
    private let client = ApiClient.shared

    private init() {}

    func fetchAllAccounts() async throws -> [AccountDto] {
        var allAccounts: [AccountDto] = []
        var page = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: "100")
            ]
            let response: AccountsResponse = try await client.request(path: "/api/v1/accounts", queryItems: queryItems)
            allAccounts.append(contentsOf: response.accounts)
            totalPages = response.pagination.totalPages
            page += 1
        } while page <= totalPages

        return allAccounts
    }

    func fetchBalanceSheet() async throws -> BalanceSheetResponse {
        return try await client.request(path: "/api/v1/balance_sheet")
    }

    func fetchRecentTransactions(startDate: String) async throws -> [TransactionListItemDto] {
        var allTransactions: [TransactionListItemDto] = []
        var page = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: "100"),
                URLQueryItem(name: "start_date", value: startDate)
            ]
            let response: TransactionsResponse = try await client.request(path: "/api/v1/transactions", queryItems: queryItems)
            allTransactions.append(contentsOf: response.transactions)
            totalPages = response.pagination.totalPages
            page += 1
        } while page <= totalPages

        return allTransactions
    }
}
