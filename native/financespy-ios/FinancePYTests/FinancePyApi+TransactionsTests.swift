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
}
