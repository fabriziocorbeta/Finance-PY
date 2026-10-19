import XCTest
import SwiftUI
import SwiftData
@testable import FinancePY

final class FinancePyApiTests: XCTestCase {

    override func setUp() {
        super.setUp()
        URLSessionConfiguration.swizzleDefaultConfiguration()
        MockURLProtocol.requestHandler = nil
    }

    func testFetchAllAccountsSuccess() async throws {
        let accountDto = AccountDto(id: "1", name: "Cash", balanceCents: 1000, cashBalanceCents: 1000, currency: "USD", classification: "asset", accountType: "cash", subtype: nil, status: "active", updatedAt: "2023-01-01")
        let paginationDto = PaginationDto(page: 1, perPage: 100, totalCount: 1, totalPages: 1)
        let responseDto = AccountsResponse(accounts: [accountDto], pagination: paginationDto)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(responseDto)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let accounts = try await FinancePyApi.shared.fetchAllAccounts()
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts.first?.id, "1")
    }

    func testFetchBalanceSheetSuccess() async throws {
        let json = """
        {"currency":"PYG","net_worth":{"amount":-8403581,"currency":"PYG","formatted":"-8.403.581 ₲"},"assets":{"amount":18378948,"currency":"PYG","formatted":"18.378.948 ₲"},"liabilities":{"amount":26782529,"currency":"PYG","formatted":"26.782.529 ₲"}}
        """
        let data = json.data(using: .utf8)!

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let balanceSheet = try await FinancePyApi.shared.fetchBalanceSheet()
        XCTAssertEqual(balanceSheet.currency, "PYG")
        XCTAssertEqual(balanceSheet.netWorth.amount, "-8403581")
        XCTAssertEqual(balanceSheet.netWorth.currency, "PYG")
        XCTAssertEqual(balanceSheet.netWorth.formatted, "-8.403.581 ₲")
        XCTAssertEqual(balanceSheet.assets.amount, "18378948")
        XCTAssertEqual(balanceSheet.assets.currency, "PYG")
        XCTAssertEqual(balanceSheet.assets.formatted, "18.378.948 ₲")
        XCTAssertEqual(balanceSheet.liabilities.amount, "26782529")
        XCTAssertEqual(balanceSheet.liabilities.currency, "PYG")
        XCTAssertEqual(balanceSheet.liabilities.formatted, "26.782.529 ₲")
    }

    func testFormatMoneyWithProductionPayload() {
        let netWorth = MoneyDto(amount: AnyStringAmount(wrappedValue: "-8403581"), currency: "PYG", formatted: "-8.403.581 ₲")
        XCTAssertEqual(Formatters.formatMoney(netWorth), "-8.403.581 ₲")

        let fallbackWithAmount = MoneyDto(amount: AnyStringAmount(wrappedValue: "-8403581"), currency: "PYG")
        XCTAssertEqual(Formatters.formatMoney(fallbackWithAmount), "PYG -8403581")

        let fallbackWithCents = MoneyDto(cents: 1000, currency: "USD")
        XCTAssertEqual(Formatters.formatMoney(fallbackWithCents), Formatters.formatCents(1000, currency: "USD"))

        let empty = MoneyDto()
        XCTAssertEqual(Formatters.formatMoney(empty), "--")
    }

    @MainActor
    func testDashboardViewRendersBalanceSheetSnapshot() throws {
        let json = """
        {"currency":"PYG","net_worth":{"amount":-8403581,"currency":"PYG","formatted":"-8.403.581 ₲"},"assets":{"amount":18378948,"currency":"PYG","formatted":"18.378.948 ₲"},"liabilities":{"amount":26782529,"currency":"PYG","formatted":"26.782.529 ₲"}}
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let balanceSheet = try decoder.decode(BalanceSheetResponse.self, from: data)

        let schema = Schema([AccountEntity.self, EntryEntity.self, TransactionEntity.self, ReceivableEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)

        let syncEngine = SyncEngine(modelContext: context)
        syncEngine.balanceSheet = balanceSheet

        let view = DashboardView(syncEngine: syncEngine)
            .modelContainer(container)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let hostingController = UIHostingController(rootView: view)
        hostingController.view.frame = window.bounds
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        let uiImage = renderer.image { ctx in
            hostingController.view.layer.render(in: ctx.cgContext)
        }

        let pngData = try XCTUnwrap(uiImage.pngData())
        let outputPath = "/tmp/dashboard_patrimonio_neto.png"
        try pngData.write(to: URL(fileURLWithPath: outputPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputPath))
    }

    func testFetchRecentTransactionsSuccess() async throws {
        let accountRef = AccountRefDto(id: "1", name: "Acc", accountType: "cash")
        let transactionDto = TransactionListItemDto(id: "1", date: "2023-01-01", amountCents: 1000, signedAmountCents: -1000, currency: "USD", name: "Tx", classification: "expense", account: accountRef, category: nil, merchant: nil, location: nil, createdAt: "2023-01-01", updatedAt: "2023-01-01")
        let paginationDto = PaginationDto(page: 1, perPage: 100, totalCount: 1, totalPages: 1)
        let responseDto = TransactionsResponse(transactions: [transactionDto], pagination: paginationDto)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(responseDto)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let transactions = try await FinancePyApi.shared.fetchRecentTransactions(startDate: "2023-01-01")
        XCTAssertEqual(transactions.count, 1)
        XCTAssertEqual(transactions.first?.id, "1")
    }

    func testApiError4xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
            return (response, "Bad Request".data(using: .utf8)!)
        }

        do {
            _ = try await FinancePyApi.shared.fetchAllAccounts()
            XCTFail("Expected error")
        } catch NetworkError.httpError(let code, _) {
            XCTAssertEqual(code, 400)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testApiError5xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, "Server Error".data(using: .utf8)!)
        }

        do {
            _ = try await FinancePyApi.shared.fetchAllAccounts()
            XCTFail("Expected error")
        } catch NetworkError.httpError(let code, _) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testApiMalformedResponse() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "not json".data(using: .utf8)!)
        }

        do {
            _ = try await FinancePyApi.shared.fetchAllAccounts()
            XCTFail("Expected error")
        } catch NetworkError.decodingError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
