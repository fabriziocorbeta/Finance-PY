import XCTest
@testable import FinancePY

final class FinancePyApiReportsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLSessionConfiguration.swizzleDefaultConfiguration()
        MockURLProtocol.requestHandler = nil
    }

    func testFetchReportsSummarySuccess() async throws {
        let period = ReportPeriodDto(startDate: "2023-01-01", endDate: "2023-01-31", type: "monthly")
        let summaryMetrics = ReportSummaryMetricsDto(income: 1000.0, incomeChangePct: 10.0, expense: 500.0, expenseChangePct: 5.0, netSavings: 500.0, budgetUsedPct: nil)
        let netWorth = ReportNetWorthDto(current: 5000.0, totalAssets: 6000.0, totalLiabilities: 1000.0, change: nil, changePct: nil)
        let breakdown = ReportTransactionsBreakdownDto(income: [], expense: [])

        let summaryDto = ReportsSummaryDto(
            period: period,
            currency: "USD",
            summary: summaryMetrics,
            trends: [],
            netWorth: netWorth,
            transactionsBreakdown: breakdown,
            investmentMetrics: nil,
            investmentFlows: nil
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(summaryDto)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let result = try await FinancePyApi.shared.fetchReportsSummary()
        XCTAssertEqual(result.currency, "USD")
    }

    func testApi4xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, "Bad Request".data(using: .utf8)!)
        }
        do {
            _ = try await FinancePyApi.shared.fetchReportsSummary()
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
            _ = try await FinancePyApi.shared.fetchReportsSummary()
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
            _ = try await FinancePyApi.shared.fetchReportsSummary()
            XCTFail("Expected error")
        } catch NetworkError.decodingError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
