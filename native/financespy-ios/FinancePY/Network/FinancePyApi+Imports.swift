import Foundation

// POST /api/v1/imports returns this same shape regardless of import type
// (UpayImport, PdfImport, ...) -- matches the Android client's
// UpayImportResultDto, reused across both import flows below instead of
// duplicating it per type.
struct ImportStatusDetailDto: Codable {
    let uploaded: Bool?
    let configured: Bool?
    let cleaned: Bool?
    let publishable: Bool?
    let revertable: Bool?
    let terminal: Bool?
}

struct ImportStatsDto: Codable {
    let rowsCount: Int
    let validRowsCount: Int
    let invalidRowsCount: Int
}

struct ImportResultDto: Codable, Identifiable {
    let id: String
    let type: String
    let status: String
    let accountId: String?
    let error: String?
    let statusDetail: ImportStatusDetailDto?
    let stats: ImportStatsDto?
}

struct ImportResultEnvelope: Codable {
    let data: ImportResultDto
}

struct PdfImportRowFieldsDto: Codable {
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

struct PdfImportRowsEnvelope: Codable {
    let data: [PdfImportRowDto]
}

extension FinancePyApi {
    func uploadUpayImport(accountId: String, fileData: Data, fileName: String) async throws -> ImportResultDto {
        let envelope: ImportResultEnvelope = try await ApiClient.shared.uploadMultipart(
            path: "/api/v1/imports",
            fields: [
                "type": "UpayImport",
                "account_id": accountId,
                "publish": "true"
            ],
            fileField: "file",
            fileData: fileData,
            fileName: fileName,
            mimeType: "text/csv"
        )
        return envelope.data
    }

    // Deliberately does NOT send publish=true: unlike Upay's auto-publish,
    // the AI-extracted rows need a human to look at what it read off the PDF
    // before any of it becomes real transactions -- see fetchPdfImportRows /
    // publishImport, called only after the user reviews and confirms.
    func uploadPdfStatement(accountId: String, fileData: Data, fileName: String) async throws -> ImportResultDto {
        let envelope: ImportResultEnvelope = try await ApiClient.shared.uploadMultipart(
            path: "/api/v1/imports",
            fields: [
                "type": "PdfImport",
                "account_id": accountId
            ],
            fileField: "file",
            fileData: fileData,
            fileName: fileName,
            mimeType: "application/pdf"
        )
        return envelope.data
    }

    func fetchImport(id: String) async throws -> ImportResultDto {
        let envelope: ImportResultEnvelope = try await ApiClient.shared.request(path: "/api/v1/imports/\(id)")
        return envelope.data
    }

    func fetchPdfImportRows(id: String) async throws -> [PdfImportRowDto] {
        let queryItems = [URLQueryItem(name: "per_page", value: "100")]
        let envelope: PdfImportRowsEnvelope = try await ApiClient.shared.request(path: "/api/v1/imports/\(id)/rows", queryItems: queryItems)
        return envelope.data
    }

    func publishImport(id: String) async throws -> ImportResultDto {
        let envelope: ImportResultEnvelope = try await ApiClient.shared.request(method: "POST", path: "/api/v1/imports/\(id)/publish")
        return envelope.data
    }
}
