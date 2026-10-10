import Foundation

struct TagRefDto: Codable {
    let id: String
    let name: String
    let color: String
}

struct TransferInfoDto: Codable {
    let id: String
    let amount: String?
    let currency: String?
    let otherAccount: AccountRefDto?
}

struct TransactionDetailDto: Codable {
    let id: String
    let date: String
    let amount: String
    let amountCents: Int64
    let signedAmountCents: Int64
    let currency: String
    let name: String
    let notes: String?
    let classification: String
    let account: AccountRefDto
    let category: CategoryRefDto?
    let merchant: MerchantRefDto?
    let tags: [TagRefDto]
    let transfer: TransferInfoDto?
    let createdAt: String
    let updatedAt: String
}

struct CreateTransactionRequest: Encodable {
    let transaction: CreateTransactionBody
}

struct CreateTransactionBody: Encodable {
    let accountId: String
    let date: String
    let amount: String
    let nature: String
    let name: String
    let notes: String?
    let currency: String?
    let categoryId: String?
    let merchantId: String?
    let tagIds: [String]?
}

struct UpdateTransactionRequest: Encodable {
    let transaction: UpdateTransactionBody
}

struct UpdateTransactionBody: Encodable {
    let accountId: String?
    let date: String?
    let amount: String?
    let nature: String?
    let name: String?
    let notes: String?
    let currency: String?
    let categoryId: String?
    let merchantId: String?
    let tagIds: [String]?
}

extension FinancePyApi {
    func createTransaction(body: CreateTransactionBody) async throws -> TransactionDetailDto {
        let request = CreateTransactionRequest(transaction: body)
        return try await ApiClient.shared.request(method: "POST", path: "/api/v1/transactions", body: request)
    }

    func updateTransaction(id: String, body: UpdateTransactionBody) async throws -> TransactionDetailDto {
        let request = UpdateTransactionRequest(transaction: body)
        return try await ApiClient.shared.request(method: "PATCH", path: "/api/v1/transactions/\(id)", body: request)
    }

    func deleteTransaction(id: String) async throws -> EmptyResponse {
        return try await ApiClient.shared.request(method: "DELETE", path: "/api/v1/transactions/\(id)")
    }
}
