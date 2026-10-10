import Foundation

// MARK: - DTOs

struct SaleItemDto: Codable, Identifiable, Hashable {
    var id: String?
    var saleId: String?
    var productId: String
    var productName: String?
    var productSku: String?
    var quantity: Int
    var unitPrice: Double
    var subtotal: Double?
    var createdAt: String?
    var updatedAt: String?
    var _destroy: Bool?
}

struct SaleDto: Codable, Identifiable {
    let id: String
    let saleNumber: Int?
    let clientName: String?
    let status: String
    let currency: String
    let paymentMethod: String?
    let invoiceNumber: String?
    let condition: String?
    let notes: String?
    let deliveryAddress: String?
    let deliveryDate: String?
    let carrier: String?
    let accountId: String?
    let total: Double
    let createdAt: String?
    let updatedAt: String?
    let saleItems: [SaleItemDto]?
}

struct SalesResponseDto: Codable {
    let data: [SaleDto]
}

struct SalePayload: Codable {
    let sale: SaleDataPayload
}

struct SaleDataPayload: Codable {
    var clientName: String?
    var currency: String?
    var notes: String?
    var accountId: String?
    var saleItemsAttributes: [SaleItemAttributes]?
}

struct SaleItemAttributes: Codable, Identifiable {
    var uniqueId = UUID()
    var id: String?
    var productId: String
    var quantity: Int
    var unitPrice: Double
    var _destroy: Bool?
}

extension FinancePyApi {
    func fetchSales() async throws -> [SaleDto] {
        let queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        let response: SalesResponseDto = try await client.request(path: "/api/v1/sales", queryItems: queryItems)
        return response.data
    }

    func fetchSale(id: String) async throws -> SaleDto {
        let response: SaleDto = try await client.request(path: "/api/v1/sales/\(id)")
        return response
    }

    func createSale(payload: SaleDataPayload) async throws -> SaleDto {
        let body = SalePayload(sale: payload)
        let response: SaleDto = try await client.request(method: "POST", path: "/api/v1/sales", body: body)
        return response
    }

    func updateSale(id: String, payload: SaleDataPayload) async throws -> SaleDto {
        let body = SalePayload(sale: payload)
        let response: SaleDto = try await client.request(method: "PATCH", path: "/api/v1/sales/\(id)", body: body)
        return response
    }

    func deleteSale(id: String) async throws {
        try await client.request(method: "DELETE", path: "/api/v1/sales/\(id)")
    }

    func completeSale(id: String) async throws -> SaleDto {
        let response: SaleDto = try await client.request(method: "POST", path: "/api/v1/sales/\(id)/complete")
        return response
    }

    func cancelSale(id: String) async throws -> SaleDto {
        let response: SaleDto = try await client.request(method: "POST", path: "/api/v1/sales/\(id)/cancel")
        return response
    }
}
