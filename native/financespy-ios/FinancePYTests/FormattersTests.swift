import XCTest
@testable import FinancePY

final class FormattersTests: XCTestCase {
    private let locale = Locale(identifier: "es_PY")

    func testFormatAmountPYGHasNoFractionDigits() {
        let formatted = Formatters.formatAmount(983998.4349, currency: "PYG", locale: locale)
        XCTAssertTrue(formatted.contains("983.998"), formatted)
        XCTAssertFalse(formatted.contains(","), formatted)
    }

    func testFormatAmountUSDHasTwoFractionDigits() {
        let formatted = Formatters.formatAmount(675, currency: "USD", locale: locale)
        XCTAssertTrue(formatted.contains("675,00"), formatted)
    }
}
