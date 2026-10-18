import XCTest
@testable import FinancePY

final class FinancePyApiAccountsWriteTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLSessionConfiguration.swizzleDefaultConfiguration()
        MockURLProtocol.requestHandler = nil
    }

    func testCreateAccountSuccess() async throws {
        let accountDto = AccountDto(id: "1", name: "New Acc", balanceCents: 0, cashBalanceCents: 0, currency: "USD", classification: "asset", accountType: "cash", subtype: nil, status: "active", updatedAt: "2023-01-01")
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(accountDto)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let body = CreateAccountBody(accountableType: "Depository", name: "New Acc", balance: 0, currency: "USD", institutionName: nil, notes: nil, accountableAttributes: nil)
        let result = try await FinancePyApi.shared.createAccount(body: body)
        XCTAssertEqual(result.id, "1")
    }

    func testCreateAccount4xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, "Bad Request".data(using: .utf8)!)
        }

        do {
            let body = CreateAccountBody(accountableType: "Depository", name: "New Acc", balance: 0, currency: "USD", institutionName: nil, notes: nil, accountableAttributes: nil)
            _ = try await FinancePyApi.shared.createAccount(body: body)
            XCTFail("Expected error")
        } catch NetworkError.httpError(let code, _) {
            XCTAssertEqual(code, 400)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateAccount5xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, "Server Error".data(using: .utf8)!)
        }

        do {
            let body = CreateAccountBody(accountableType: "Depository", name: "New Acc", balance: 0, currency: "USD", institutionName: nil, notes: nil, accountableAttributes: nil)
            _ = try await FinancePyApi.shared.createAccount(body: body)
            XCTFail("Expected error")
        } catch NetworkError.httpError(let code, _) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateAccountMalformed() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "not json".data(using: .utf8)!)
        }

        do {
            let body = CreateAccountBody(accountableType: "Depository", name: "New Acc", balance: 0, currency: "USD", institutionName: nil, notes: nil, accountableAttributes: nil)
            _ = try await FinancePyApi.shared.createAccount(body: body)
            XCTFail("Expected error")
        } catch NetworkError.decodingError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
