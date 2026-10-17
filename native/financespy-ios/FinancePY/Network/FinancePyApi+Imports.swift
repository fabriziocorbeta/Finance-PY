import Foundation

// MARK: - DTOs

struct PdfImportRowFieldsDto: Codable, Identifiable {
    let id = UUID().uuidString
    let date: String?
    let amount: String?
    let currency: String?
    let name: String?
    let category: String?
    let notes: String?
}

struct PdfImportRowDto: Codable, Identifiable {
    let id: String
    let rowNumber: Int
    let valid: Bool
    let errors: [String]
    let fields: PdfImportRowFieldsDto
}

struct PdfImportRowsResponseDto: Codable {
    let data: [PdfImportRowDto]
}

struct UpayImportStatusDetailDto: Codable {
    let uploaded: Bool?
    let configured: Bool?
    let cleaned: Bool?
    let publishable: Bool?
    let revertable: Bool?
    let terminal: Bool?
}

struct UpayImportStatsDto: Codable {
    let rowsCount: Int
    let validRowsCount: Int
    let invalidRowsCount: Int
}

struct UpayImportResultDto: Codable {
    let id: String
    let type: String
    let status: String
    let accountId: String?
    let error: String?
    let statusDetail: UpayImportStatusDetailDto?
    let stats: UpayImportStatsDto?
}

struct UpayImportResponseDto: Codable {
    let data: UpayImportResultDto
}

typealias PdfImportResultDto = UpayImportResultDto

// MARK: - API Methods

extension ApiClient {
    func uploadPdfStatement(accountId: String, fileData: Data, fileName: String) async throws -> PdfImportResultDto {
        let response: UpayImportResponseDto = try await uploadMultipart(
            path: "/api/v1/imports",
            fileData: fileData,
            fileName: fileName,
            mimeType: "application/pdf",
            fields: [
                "type": "PdfImport",
                "account_id": accountId
            ]
        )
        return response.data
    }

    func fetchPdfImportRows(importId: String) async throws -> [PdfImportRowDto] {
        let response: PdfImportRowsResponseDto = try await request(
            path: "/api/v1/imports/\(importId)/rows",
            queryItems: [URLQueryItem(name: "per_page", value: "100")]
        )
        return response.data
    }

    func publishImport(importId: String) async throws {
        let _: EmptyResponse = try await request(
            method: "POST",
            path: "/api/v1/imports/\(importId)/publish"
        )
    }

    func uploadUpayImport(accountId: String, fileData: Data, fileName: String) async throws -> UpayImportResultDto {
        let response: UpayImportResponseDto = try await uploadMultipart(
            path: "/api/v1/imports",
            fileData: fileData,
            fileName: fileName,
            mimeType: "text/csv",
            fields: [
                "type": "UpayImport",
                "account_id": accountId,
                "publish": "true"
            ]
        )
        return response.data
    }

    func fetchImport(importId: String) async throws -> UpayImportResultDto {
        let response: UpayImportResponseDto = try await request(
            path: "/api/v1/imports/\(importId)"
        )
        return response.data
    }
}
