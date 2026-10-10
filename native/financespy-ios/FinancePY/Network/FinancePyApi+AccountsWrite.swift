import Foundation

struct CreateAccountBody: Encodable {
    let accountableType: String
    let name: String
    let balance: Double
    let currency: String
    let institutionName: String?
    let notes: String?
    let accountableAttributes: CreateAccountAccountableAttributes?
}

struct CreateAccountAccountableAttributes: Encodable {
    let availableCredit: Double?
    let apr: Double?
    let make: String?
    let model: String?
    let year: Int?
    let interestRate: Double?
    let termMonths: Int?
    let subtype: String?
}

extension FinancePyApi {
    func createAccount(body: CreateAccountBody) async throws -> AccountDto {
        return try await ApiClient.shared.request(method: "POST", path: "/api/v1/accounts", body: body)
    }
}
