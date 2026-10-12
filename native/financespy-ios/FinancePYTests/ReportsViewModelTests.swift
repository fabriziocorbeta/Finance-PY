import XCTest
import Combine
@testable import FinancePY

@MainActor
final class ReportsViewModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLSessionConfiguration.swizzleDefaultConfiguration()
        MockURLProtocol.requestHandler = nil
    }

    func testFetchReportsSuccess() async throws {
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
            let httpResponse = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (httpResponse, data)
        }

        let viewModel = ReportsViewModel()

        // Wait for debounce/init to fetch via Combine
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(viewModel.periodType, "monthly")

        // The first initialization might fetch automatically but let's just trigger one explicitly
        await viewModel.fetchReports()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNotNil(viewModel.summary)
        XCTAssertEqual(viewModel.summary?.currency, "USD")
    }

    func testFetchReportsError() async throws {
        MockURLProtocol.requestHandler = { request in
            let httpResponse = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!
            return (httpResponse, Data())
        }

        let viewModel = ReportsViewModel()
        await viewModel.fetchReports()

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.summary)
    }
}
