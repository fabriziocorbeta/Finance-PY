import XCTest
@testable import FinancePY

final class ReceivableDetailViewTests: XCTestCase {
    func testCaseInsensitiveComparison() {
        let account1 = AccountDto(id: "1", name: "Bank", balanceCents: 100, cashBalanceCents: 100, currency: "USD", classification: "asset", accountType: "Depository", subtype: "checking", status: "active", updatedAt: "")
        let account2 = AccountDto(id: "2", name: "Credit", balanceCents: 100, cashBalanceCents: 100, currency: "USD", classification: "liability", accountType: "Credit", subtype: "credit_card", status: "active", updatedAt: "")
        let account3 = AccountDto(id: "3", name: "Other", balanceCents: 100, cashBalanceCents: 100, currency: "USD", classification: "asset", accountType: "DEPOSITORY", subtype: "checking", status: "active", updatedAt: "")

        let allAccounts = [account1, account2, account3]

        let paymentAccounts = allAccounts.filter { $0.accountType?.lowercased() == "depository" && $0.status == "active" }

        XCTAssertEqual(paymentAccounts.count, 2)
        XCTAssertEqual(paymentAccounts[0].id, "1")
        XCTAssertEqual(paymentAccounts[1].id, "3")
    }
}
