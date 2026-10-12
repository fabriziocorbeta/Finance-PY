import XCTest
@testable import FinancePY

final class FinancePyApiReceivablesTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLSessionConfiguration.swizzleDefaultConfiguration()
        MockURLProtocol.requestHandler = nil
    }

    func testFetchReceivablesSuccess() async throws {
        let rec = ReceivableDto(id: "1", accountId: "1", debtorName: "Debtor", description: nil, principalCents: 100, currency: "USD", status: "active", createdAt: "2023", updatedAt: "2023", defaultInterestRate: nil, defaultPenaltyRate: nil, terms: nil, installmentSchedule: nil)
        let responseDto = ReceivablesResponseDto(data: [rec])
        let data = try JSONEncoder().encode(responseDto)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let result = try await FinancePyApi.shared.fetchReceivables()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "1")
    }

    func testApi4xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, "Bad Request".data(using: .utf8)!)
        }
        do {
            _ = try await FinancePyApi.shared.fetchReceivables()
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
            _ = try await FinancePyApi.shared.fetchReceivables()
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
            _ = try await FinancePyApi.shared.fetchReceivables()
            XCTFail("Expected error")
        } catch NetworkError.decodingError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
