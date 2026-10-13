import Foundation

extension FinancePyApi {
    func fetchMerchants() async throws -> [MerchantRefDto] {
        return try await ApiClient.shared.request(path: "/api/v1/merchants")
    }
}
