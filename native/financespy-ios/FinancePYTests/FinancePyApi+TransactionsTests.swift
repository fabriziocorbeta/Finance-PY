import XCTest
@testable import FinancePY

final class FinancePyApiTransactionsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLSessionConfiguration.swizzleDefaultConfiguration()
        MockURLProtocol.requestHandler = nil
    }

    func testCreateTransactionSuccess() async throws {
        let accRef = AccountRefDto(id: "1", name: "Acc", accountType: "cash")
        let tx = TransactionDetailDto(id: "1", date: "2023-01-01", amount: AnyStringAmount(wrappedValue: "10"), amountCents: 1000, signedAmountCents: 1000, currency: "USD", name: "Tx", notes: nil, classification: "income", account: accRef, category: nil, merchant: nil, tags: [], transfer: nil, location: nil, createdAt: "2023", updatedAt: "2023")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(tx)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let body = CreateTransactionBody(accountId: "1", date: "2023", amount: AnyStringAmount(wrappedValue: "10"), nature: "income", name: "Tx", notes: nil, currency: nil, categoryId: nil, merchantId: nil, tagIds: nil)
        let result = try await FinancePyApi.shared.createTransaction(body: body)
        XCTAssertEqual(result.id, "1")
    }

    func testApi4xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, "Bad Request".data(using: .utf8)!)
        }
        do {
            _ = try await FinancePyApi.shared.createTransaction(body: CreateTransactionBody(accountId: "1", date: "2023", amount: AnyStringAmount(wrappedValue: "10"), nature: "income", name: "Tx", notes: nil, currency: nil, categoryId: nil, merchantId: nil, tagIds: nil))
            XCTFail("Expected error")
        } catch NetworkError.httpError(let code, _) {
            XCTAssertEqual(code, 400)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testApi5xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, "Server Error".data(using: .utf8)!)
        }
        do {
            _ = try await FinancePyApi.shared.createTransaction(body: CreateTransactionBody(accountId: "1", date: "2023", amount: AnyStringAmount(wrappedValue: "10"), nature: "income", name: "Tx", notes: nil, currency: nil, categoryId: nil, merchantId: nil, tagIds: nil))
            XCTFail("Expected error")
        } catch NetworkError.httpError(let code, _) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testApiMalformed() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "not json".data(using: .utf8)!)
        }
        do {
            _ = try await FinancePyApi.shared.createTransaction(body: CreateTransactionBody(accountId: "1", date: "2023", amount: AnyStringAmount(wrappedValue: "10"), nature: "income", name: "Tx", notes: nil, currency: nil, categoryId: nil, merchantId: nil, tagIds: nil))
            XCTFail("Expected error")
        } catch NetworkError.decodingError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Request payloads (create / update)

    /// Refuses to send a write unless ApiClient.shared really goes through
    /// MockURLProtocol -- otherwise the POST/PATCH would reach production.
    private func assertSharedClientIsMocked(file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let session = Mirror(reflecting: ApiClient.shared).children.first { $0.label == "session" }?.value as? URLSession
        let mocked = session?.configuration.protocolClasses?.contains { $0 == MockURLProtocol.self } ?? false
        if !mocked { XCTFail("ApiClient.shared is not mocked; refusing to hit the network", file: file, line: line) }
        return mocked
    }

    private func bodyJSON(_ request: URLRequest) -> [String: Any]? {
        var data = request.httpBody
        if data == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            var collected = Data()
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                if read <= 0 { break }
                collected.append(buffer, count: read)
            }
            data = collected
        }
        guard let data else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func detailResponseData(id: String) throws -> Data {
        let tx = TransactionDetailDto(id: id, date: "2026-10-20", amount: AnyStringAmount(wrappedValue: "150.000"), amountCents: 150000, signedAmountCents: -150000, currency: "PYG", name: "Super", notes: nil, classification: "expense", account: AccountRefDto(id: "acc-1", name: "Caja", accountType: "depository"), category: nil, merchant: nil, tags: [], transfer: nil, location: nil, createdAt: "2026-10-20T10:00:00Z", updatedAt: "2026-10-20T10:00:00Z")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return try encoder.encode(tx)
    }

    func testCreateTransactionSendsExpectedPayload() async throws {
        guard assertSharedClientIsMocked() else { return }
        let responseData = try detailResponseData(id: "tx-new")
        var captured: URLRequest?
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { request in
            captured = request
            capturedBody = self.bodyJSON(request)
            return (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, responseData)
        }

        let body = TransactionFormPayload.createBody(
            accountId: "acc-1", date: "2026-10-20", amount: "150000", nature: "expense",
            name: "Super", notes: "", currency: "PYG", categoryId: "cat-1", merchantId: ""
        )
        let result = try await FinancePyApi.shared.createTransaction(body: body)

        XCTAssertEqual(result.id, "tx-new")
        XCTAssertEqual(captured?.httpMethod, "POST")
        XCTAssertEqual(captured?.url?.path, "/api/v1/transactions")
        let tx = try XCTUnwrap(capturedBody?["transaction"] as? [String: Any])
        XCTAssertEqual(tx["account_id"] as? String, "acc-1")
        XCTAssertEqual(tx["date"] as? String, "2026-10-20")
        XCTAssertEqual(tx["amount"] as? String, "150000")
        XCTAssertEqual(tx["nature"] as? String, "expense")
        XCTAssertEqual(tx["name"] as? String, "Super")
        XCTAssertEqual(tx["currency"] as? String, "PYG")
        XCTAssertEqual(tx["category_id"] as? String, "cat-1")
        XCTAssertNil(tx["merchant_id"], "empty picker must not send merchant_id")
        XCTAssertNil(tx["notes"], "empty notes must not be sent")
        XCTAssertNil(tx["tag_ids"])
    }

    func testUpdateTransactionSendsOnlyEditedFinancialFields() async throws {
        guard assertSharedClientIsMocked() else { return }
        let responseData = try detailResponseData(id: "tx-1")
        var captured: URLRequest?
        var capturedBody: [String: Any]?
        MockURLProtocol.requestHandler = { request in
            captured = request
            capturedBody = self.bodyJSON(request)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, responseData)
        }

        let original = TransactionFormSnapshot(date: "2026-10-20", amountText: "150000", nature: "expense", notes: "vieja")
        let body = TransactionFormPayload.updateBody(
            original: original, notesKnown: true, date: "2026-10-20", amount: "150000", nature: "expense",
            name: "Supermercado", notes: "nueva", categoryId: "cat-2", merchantId: "mer-1"
        )
        _ = try await FinancePyApi.shared.updateTransaction(id: "tx-1", body: body)

        XCTAssertEqual(captured?.httpMethod, "PATCH")
        XCTAssertEqual(captured?.url?.path, "/api/v1/transactions/tx-1")
        let tx = try XCTUnwrap(capturedBody?["transaction"] as? [String: Any])
        XCTAssertEqual(tx["name"] as? String, "Supermercado")
        XCTAssertEqual(tx["notes"] as? String, "nueva")
        XCTAssertEqual(tx["category_id"] as? String, "cat-2")
        XCTAssertEqual(tx["merchant_id"] as? String, "mer-1")
        // Unchanged amount/nature/date are left out so split parents can still be renamed.
        XCTAssertTrue(tx["amount"] == nil || tx["amount"] is NSNull)
        XCTAssertNil(tx["nature"])
        XCTAssertNil(tx["date"])
        XCTAssertNil(tx["account_id"])
        XCTAssertNil(tx["tag_ids"], "omitting tag_ids keeps the server's tags")
    }

    func testUpdateTransactionSendsAmountWithNatureWhenTypeFlips() throws {
        let original = TransactionFormSnapshot(date: "2026-10-20", amountText: "150000", nature: "expense", notes: "")
        let body = TransactionFormPayload.updateBody(
            original: original, notesKnown: false, date: "2026-10-21", amount: "150000", nature: "income",
            name: "Reintegro", notes: "", categoryId: "", merchantId: ""
        )
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(UpdateTransactionRequest(transaction: body))) as? [String: Any])
        let tx = try XCTUnwrap(json["transaction"] as? [String: Any])
        XCTAssertEqual(tx["amount"] as? String, "150000")
        XCTAssertEqual(tx["nature"] as? String, "income")
        XCTAssertEqual(tx["date"] as? String, "2026-10-21")
        XCTAssertNil(tx["notes"], "notes unknown (offline prefill) must never be sent")
    }

    func testAmountInputNormalization() {
        XCTAssertEqual(Formatters.normalizedAmountInput("150.000", currency: "PYG"), "150000")
        XCTAssertEqual(Formatters.normalizedAmountInput("150000", currency: "PYG"), "150000")
        XCTAssertEqual(Formatters.normalizedAmountInput("12,50", currency: "USD"), "12.50")
        XCTAssertEqual(Formatters.normalizedAmountInput("1.234,56", currency: "USD"), "1234.56")
        XCTAssertNil(Formatters.normalizedAmountInput("0", currency: "PYG"))
        XCTAssertNil(Formatters.normalizedAmountInput("abc", currency: "PYG"))
        XCTAssertEqual(Formatters.centsToAmountText(-150000, currency: "PYG"), "150000")
        XCTAssertEqual(Formatters.centsToAmountText(1205, currency: "USD"), "12.05")
    }
}
