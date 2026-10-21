import XCTest
@testable import FinancePY

final class FormattersTests: XCTestCase {

    // MARK: - Account types

    func testAccountTypeLabelCoversEveryServerAccountableType() {
        // Strings exactly as /api/v1/accounts serializes `accountable_type.underscore`.
        let expected: [String: String] = [
            "depository": "Cuenta bancaria",
            "credit_card": "Tarjeta de crédito",
            "loan": "Préstamo",
            "investment": "Inversión",
            "crypto": "Cripto",
            "property": "Inmueble",
            "vehicle": "Vehículo",
            "other_asset": "Otro activo",
            "other_liability": "Otro pasivo",
            "receivable": "Cuenta a cobrar"
        ]
        for (raw, label) in expected {
            XCTAssertEqual(Formatters.accountTypeLabel(raw), label, raw)
        }
    }

    func testAccountTypeLabelAcceptsCamelCaseAndCapitalizedForms() {
        XCTAssertEqual(Formatters.accountTypeLabel("CreditCard"), "Tarjeta de crédito")
        XCTAssertEqual(Formatters.accountTypeLabel("Credit_Card"), "Tarjeta de crédito")
        XCTAssertEqual(Formatters.accountTypeLabel("OtherLiability"), "Otro pasivo")
        XCTAssertEqual(Formatters.accountTypeLabel("Depository"), "Cuenta bancaria")
    }

    func testAccountTypeLabelFallsBackToHumanizedValue() {
        XCTAssertEqual(Formatters.accountTypeLabel("some_new_type"), "Some new type")
        XCTAssertEqual(Formatters.accountTypeLabel("SomeNewType"), "Some new type")
        XCTAssertEqual(Formatters.accountTypeLabel("cash"), "Cash")
        XCTAssertEqual(Formatters.accountTypeLabel(""), "")
    }

    // MARK: - Statuses

    func testSaleStatusLabels() {
        XCTAssertEqual(Formatters.saleStatusLabel("draft"), "Borrador")
        XCTAssertEqual(Formatters.saleStatusLabel("completed"), "Completada")
        XCTAssertEqual(Formatters.saleStatusLabel("cancelled"), "Cancelada")
        XCTAssertEqual(Formatters.saleStatusLabel("on_hold"), "On hold")
    }

    func testPurchaseOrderStatusLabels() {
        XCTAssertEqual(Formatters.purchaseOrderStatusLabel("draft"), "Borrador")
        XCTAssertEqual(Formatters.purchaseOrderStatusLabel("received"), "Recibido")
        XCTAssertEqual(Formatters.purchaseOrderStatusLabel("cancelled"), "Cancelado")
    }

    // MARK: - Dates

    private func mediumSpanish(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_PY")
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func testFormatDateRendersPlainDayInSpanish() {
        let result = Formatters.formatDate("2026-11-05")

        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let day = utc.date(from: DateComponents(year: 2026, month: 11, day: 5))!
        XCTAssertEqual(result, mediumSpanish(day, timeZone: utc.timeZone))
        XCTAssertTrue(result.hasPrefix("5 nov"), result)
        XCTAssertTrue(result.hasSuffix("2026"), result)
        XCTAssertFalse(result.contains("-"), result)
    }

    func testFormatDateDoesNotShiftDaysAcrossYearBoundaries() {
        XCTAssertTrue(Formatters.formatDate("2026-01-01").hasPrefix("1 ene"))
        XCTAssertTrue(Formatters.formatDate("2026-12-31").hasPrefix("31 dic"))
    }

    func testFormatDateParsesIsoTimestamps() {
        let instant = ISO8601DateFormatter().date(from: "2026-11-05T15:00:00Z")!
        let expected = mediumSpanish(instant, timeZone: .current)

        XCTAssertEqual(Formatters.formatDate("2026-11-05T15:00:00Z"), expected)
        XCTAssertEqual(Formatters.formatDate("2026-11-05T12:00:00-03:00"), expected)
        XCTAssertEqual(Formatters.formatDate("2026-11-05T15:00:00.123Z"), expected)
    }

    func testFormatDateFallsBackToRawString() {
        XCTAssertEqual(Formatters.formatDate("ayer"), "ayer")
        XCTAssertEqual(Formatters.formatDate("05/11/2026"), "05/11/2026")
        XCTAssertEqual(Formatters.formatDate("2026-13-45"), "2026-13-45")
        XCTAssertEqual(Formatters.formatDate(""), "")
    }
}
