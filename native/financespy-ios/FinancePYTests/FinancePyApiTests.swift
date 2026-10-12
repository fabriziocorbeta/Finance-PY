import XCTest
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
        let money = MoneyDto(cents: 1000, amount: "10.00", currency: "USD")
        let responseDto = BalanceSheetResponse(currency: "USD", netWorth: money, assets: money, liabilities: money)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(responseDto)

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }

        let balanceSheet = try await FinancePyApi.shared.fetchBalanceSheet()
        XCTAssertEqual(balanceSheet.currency, "USD")
        XCTAssertEqual(balanceSheet.netWorth.cents, 1000)
    }

    func testFetchRecentTransactionsSuccess() async throws {
        let accountRef = AccountRefDto(id: "1", name: "Acc", accountType: "cash")
        let transactionDto = TransactionListItemDto(id: "1", date: "2023-01-01", amountCents: 1000, signedAmountCents: -1000, currency: "USD", name: "Tx", classification: "expense", account: accountRef, category: nil, merchant: nil, createdAt: "2023-01-01", updatedAt: "2023-01-01")
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
