import Foundation

// MARK: - DTOs

struct ReceivablesResponse: Codable {
    let data: [ReceivableDto]
    let meta: ReceivablesMetaDto?
}

struct ReceivableResponse: Codable {
    let data: ReceivableDto
}

struct ReceivablesMetaDto: Codable {
    let currentPage: Int
    let nextPage: Int?
    let prevPage: Int?
    let totalPages: Int
    let totalCount: Int
    let perPage: Int
}

struct InstallmentDto: Codable, Identifiable {
    var id: String { String(number) }
    let number: Int
    let dueDate: String
    let amount: Double
    let paidAmount: Double
    let status: String
    let paidAt: String?
}

struct ReceivableDto: Codable {
    let id: String
    let accountId: String?
    let name: String?
    let totalAmount: Double?
    let balance: Double?
    let balanceCents: Int64?
    let originalBalance: Double?
    let originalBalanceCents: Int64?
    let paidAmount: Double?
    let paidAmountCents: Int64?
    let percentPaid: Double?
    let installmentCount: Int?
    let dueDay: Int?
    let currency: String?
    let notes: String?
    let updatedAt: String?
    let installmentSchedule: [InstallmentDto]?
}

struct CreateReceivableRequest: Codable {
    let receivable: CreateReceivableBody
}

struct CreateReceivableBody: Codable {
    let name: String
    let totalAmount: Double
    let balance: Double?
    let installmentCount: Int?
    let dueDay: Int?
    let currency: String
    let notes: String?
}

struct UpdateReceivableRequest: Codable {
    let receivable: UpdateReceivableBody
}

struct UpdateReceivableBody: Codable {
    let name: String?
    let totalAmount: Double?
    let balance: Double?
    let installmentCount: Int?
    let dueDay: Int?
    let currency: String?
    let notes: String?
}

struct CreateTransferRequest: Codable {
    let transfer: CreateTransferBody
}

struct CreateTransferBody: Codable {
    let fromAccountId: String
    let toAccountId: String
    let amount: Double
    let date: String
}

// MARK: - API Methods

extension FinancePyApi {
    func fetchReceivables() async throws -> [ReceivableDto] {
        var allReceivables: [ReceivableDto] = []
        var page = 1
        var totalPages = 1

        repeat {
            let queryItems = [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "per_page", value: "100")
            ]

            let response: ReceivablesResponse = try await ApiClient.shared.request(
                path: "/api/v1/receivables",
                queryItems: queryItems
            )

            allReceivables.append(contentsOf: response.data)
            totalPages = response.meta?.totalPages ?? 1
            page += 1
        } while page <= totalPages

        return allReceivables
    }

    func fetchReceivable(id: String) async throws -> ReceivableDto {
        let response: ReceivableResponse = try await ApiClient.shared.request(path: "/api/v1/receivables/\(id)")
        return response.data
    }

    func createReceivable(_ body: CreateReceivableBody) async throws -> ReceivableDto {
        let request = CreateReceivableRequest(receivable: body)
        let response: ReceivableResponse = try await ApiClient.shared.request(
            method: "POST",
            path: "/api/v1/receivables",
            body: request
        )
        return response.data
    }

    func updateReceivable(id: String, _ body: UpdateReceivableBody) async throws -> ReceivableDto {
        let request = UpdateReceivableRequest(receivable: body)
        let response: ReceivableResponse = try await ApiClient.shared.request(
            method: "PATCH",
            path: "/api/v1/receivables/\(id)",
            body: request
        )
        return response.data
    }

    func deleteReceivable(id: String) async throws {
        let _: EmptyResponse = try await ApiClient.shared.request(
            method: "DELETE",
            path: "/api/v1/receivables/\(id)"
        )
    }

    func createTransfer(_ body: CreateTransferBody) async throws {
        let request = CreateTransferRequest(transfer: body)
        // Adjust response generic type based on backend transfer response if necessary
        // Typically it might return the transaction or an empty response.
        let _: EmptyResponse = try await ApiClient.shared.request(
            method: "POST",
            path: "/api/v1/transfers",
            body: request
        )
    }
}
