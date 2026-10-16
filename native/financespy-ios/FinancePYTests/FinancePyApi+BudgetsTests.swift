import XCTest
@testable import FinancePY

final class FinancePyApiBudgetsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLSessionConfiguration.swizzleDefaultConfiguration()
        MockURLProtocol.requestHandler = nil
    }

    func testFetchBudgetsSuccess() async throws {
        let budget = BudgetDto(id: "1", name: "Budget", currency: "USD", periodType: "monthly", isActive: true, notes: nil, budgetCategories: [], lastUpdatedAt: "2023-01-01", createdAt: "2023-01-01", updatedAt: "2023-01-01")
        let responseDto = BudgetsResponseDto(data: [budget])
        let data = try JSONEncoder().encode(responseDto)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let result = try await FinancePyApi.shared.fetchBudgets()
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.id, "1")
    }

    func testFetchBudgets4xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        do {
            _ = try await FinancePyApi.shared.fetchBudgets()
            XCTFail()
        } catch NetworkError.httpError(let code, _) {
            XCTAssertEqual(code, 404)
        } catch {
            XCTFail()
        }
    }

    func testApi5xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, "Server Error".data(using: .utf8)!)
        }
        do {
            _ = try await FinancePyApi.shared.fetchBudgets()
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
            _ = try await FinancePyApi.shared.fetchBudgets()
            XCTFail("Expected error")
        } catch NetworkError.decodingError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCreateBudgetDuplicate422Error() async {
        // This test simulates the concurrent error that the view model now specifically catches.
        let jsonError = """
        {"error":"validation_failed","message":"Budget could not be created","errors":["Start date ya esta en uso","End date ya esta en uso"]}
        """
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 422, httpVersion: nil, headerFields: nil)!
            return (response, jsonError.data(using: .utf8)!)
        }
        do {
            _ = try await FinancePyApi.shared.createBudget(expectedIncome: 0, startDate: "2026-10-01", endDate: nil)
            XCTFail("Expected 422 error")
        } catch NetworkError.httpError(let code, let message) {
            XCTAssertEqual(code, 422)
            XCTAssertTrue(message?.contains("ya esta en uso") == true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
