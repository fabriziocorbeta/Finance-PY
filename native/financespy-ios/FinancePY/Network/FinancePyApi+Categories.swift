import Foundation

struct CategoriesResponse: Codable {
    let categories: [CategoryRefDto]
}

extension FinancePyApi {
    func fetchCategories() async throws -> [CategoryRefDto] {
        let queryItems = [URLQueryItem(name: "per_page", value: "100")]
        let response: CategoriesResponse = try await ApiClient.shared.request(path: "/api/v1/categories", queryItems: queryItems)
        return response.categories
    }
}
