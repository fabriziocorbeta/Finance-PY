import Foundation

// MARK: - Products DTOs

struct ProductDto: Codable, Identifiable {
    let id: String
    let name: String
    let sku: String?
    let category: String?
    let supplier: String?
    let buyPrice: Double
    let sellPrice: Double
    let currency: String
    let stock: Int
    let minStock: Int
    let description: String?
    let createdAt: String?
    let updatedAt: String?
}

struct ProductsResponseDto: Codable {
    let data: [ProductDto]
    let meta: PaginationDto?
}

struct ProductResponseDto: Codable {
    let data: ProductDto
}

struct CreateProductRequest: Codable {
    let product: CreateProductBody
}

struct CreateProductBody: Codable {
    let name: String
    let sku: String?
    let category: String?
    let supplier: String?
    let buyPrice: Double
    let sellPrice: Double
    let currency: String
    let minStock: Int
    let initialStock: Int
    let description: String?
}

struct UpdateProductRequest: Codable {
    let product: UpdateProductBody
}

struct UpdateProductBody: Codable {
    let name: String?
    let sku: String?
    let category: String?
    let supplier: String?
    let buyPrice: Double?
    let sellPrice: Double?
    let currency: String?
    let minStock: Int?
    let description: String?
}

// MARK: - Products API Methods

extension FinancePyApi {
    func getProducts(page: Int = 1, perPage: Int = 100) async throws -> [ProductDto] {
        let queryItems = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "per_page", value: String(perPage))
        ]

        let response: ProductsResponseDto = try await ApiClient.shared.request(path: "/api/v1/products", queryItems: queryItems)
        return response.data
    }

    func getProduct(id: String) async throws -> ProductDto {
        let response: ProductResponseDto = try await ApiClient.shared.request(path: "/api/v1/products/\(id)")
        return response.data
    }

    func createProduct(request: CreateProductRequest) async throws -> ProductDto {
        let response: ProductResponseDto = try await ApiClient.shared.request(method: "POST", path: "/api/v1/products", body: request)
        return response.data
    }

    func updateProduct(id: String, request: UpdateProductRequest) async throws -> ProductDto {
        let response: ProductResponseDto = try await ApiClient.shared.request(method: "PATCH", path: "/api/v1/products/\(id)", body: request)
        return response.data
    }

    func deleteProduct(id: String) async throws {
        let _: EmptyResponse = try await ApiClient.shared.request(method: "DELETE", path: "/api/v1/products/\(id)")
    }
}
