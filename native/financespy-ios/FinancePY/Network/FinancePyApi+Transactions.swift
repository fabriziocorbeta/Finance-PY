import Foundation

struct TagRefDto: Codable {
    let id: String
    let name: String
    let color: String
}

struct TransferInfoDto: Codable {
    let id: String
    @AnyStringAmount var amount: String?
    let currency: String?
    let otherAccount: AccountRefDto?
}

struct TransactionFuelLogLineDto: Codable, Identifiable, Hashable {
    var id: String?
    var fuelType: String
    var brand: String?
    var liters: Double
    var cost: Double
}

struct TransactionFuelLogDto: Codable {
    let id: String?
    let fleetVehicleId: String
    let vehiclePlate: String?
    let odometer: Double?
    let notes: String?
    let liters: Double
    let cost: Double
    let fuelLogLines: [TransactionFuelLogLineDto]?
}

struct TransactionFuelLogLineRequestDto: Codable {
    let id: String?
    let fuelType: String
    let brand: String?
    let liters: Double
    let cost: Double
    let _destroy: Bool?
}

struct TransactionFuelLogRequestDto: Codable {
    let fleetVehicleId: String
    let odometer: Double?
    let notes: String?
    let fuelLogLinesAttributes: [TransactionFuelLogLineRequestDto]
}

struct TransactionDetailDto: Codable {
    let id: String
    let date: String
    @AnyStringAmount var amount: String?
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
    let location: TransactionLocationDto?
    let fuelLog: TransactionFuelLogDto?
    let hasInvoicePhoto: Bool?
    let invoicePhoto: InvoicePhotoDto?
    let createdAt: String
    let updatedAt: String
}

struct CreateTransactionRequest: Codable {
    let transaction: CreateTransactionBody
}

struct CreateTransactionBody: Codable {
    let accountId: String
    let date: String
    @AnyStringAmount var amount: String?
    let nature: String
    let name: String
    let notes: String?
    let currency: String?
    let categoryId: String?
    let merchantId: String?
    let tagIds: [String]?
    let latitude: Double?
    let longitude: Double?
    let fuelLog: TransactionFuelLogRequestDto?

    init(
        accountId: String,
        date: String,
        amount: String?,
        nature: String,
        name: String,
        notes: String?,
        currency: String?,
        categoryId: String?,
        merchantId: String?,
        tagIds: [String]?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        fuelLog: TransactionFuelLogRequestDto? = nil
    ) {
        self.accountId = accountId
        self.date = date
        self._amount = AnyStringAmount(wrappedValue: amount)
        self.nature = nature
        self.name = name
        self.notes = notes
        self.currency = currency
        self.categoryId = categoryId
        self.merchantId = merchantId
        self.tagIds = tagIds
        self.latitude = latitude
        self.longitude = longitude
        self.fuelLog = fuelLog
    }
}

struct UpdateTransactionRequest: Codable {
    let transaction: UpdateTransactionBody
}

struct UpdateTransactionBody: Codable {
    let accountId: String?
    let date: String?
    @AnyStringAmount var amount: String?
    let nature: String?
    let name: String?
    let notes: String?
    let currency: String?
    let categoryId: String?
    let merchantId: String?
    let tagIds: [String]?
    let latitude: Double?
    let longitude: Double?
    let fuelLog: TransactionFuelLogRequestDto?

    init(
        accountId: String?,
        date: String?,
        amount: String?,
        nature: String?,
        name: String?,
        notes: String?,
        currency: String?,
        categoryId: String?,
        merchantId: String?,
        tagIds: [String]?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        fuelLog: TransactionFuelLogRequestDto? = nil
    ) {
        self.accountId = accountId
        self.date = date
        self._amount = AnyStringAmount(wrappedValue: amount)
        self.nature = nature
        self.name = name
        self.notes = notes
        self.currency = currency
        self.categoryId = categoryId
        self.merchantId = merchantId
        self.tagIds = tagIds
        self.latitude = latitude
        self.longitude = longitude
        self.fuelLog = fuelLog
    }
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

    func uploadTransactionInvoicePhoto(
        transactionId: String,
        fileData: Data,
        fileName: String,
        mimeType: String = "image/jpeg"
    ) async throws -> TransactionDetailDto {
        try await ApiClient.shared.uploadMultipart(
            path: "/api/v1/transactions/\(transactionId)/invoice_photo",
            fields: [:],
            fileField: "invoice_photo",
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType
        )
    }

    func deleteTransactionInvoicePhoto(transactionId: String) async throws -> TransactionDetailDto {
        try await ApiClient.shared.request(
            method: "DELETE",
            path: "/api/v1/transactions/\(transactionId)/invoice_photo"
        )
    }

    func downloadTransactionInvoicePhoto(transactionId: String) async throws -> Data {
        try await ApiClient.shared.downloadData(path: "/api/v1/transactions/\(transactionId)/invoice_photo")
    }
}
