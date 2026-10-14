import XCTest
@testable import FinancePY

final class InstallmentDtoDecodingTests: XCTestCase {

    func testDecodeInstallmentWithStringAmounts() throws {
        let json = """
        {
            "number": 1,
            "due_date": "2023-10-01",
            "amount": "150.50",
            "paid_amount": "50.00",
            "status": "partial",
            "paid_at": "2023-09-15"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let installment = try decoder.decode(InstallmentDto.self, from: json)

        XCTAssertEqual(installment.amount, "150.50")
        XCTAssertEqual(installment.paidAmount, "50.00")
        XCTAssertEqual(installment.number, 1)
        XCTAssertEqual(installment.status, "partial")
    }

    func testDecodeInstallmentWithNumberAmounts() throws {
        let json = """
        {
            "number": 2,
            "due_date": "2023-11-01",
            "amount": 200.75,
            "paid_amount": 200.75,
            "status": "paid",
            "paid_at": "2023-10-15"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let installment = try decoder.decode(InstallmentDto.self, from: json)

        XCTAssertEqual(installment.amount, "200.75")
        XCTAssertEqual(installment.paidAmount, "200.75")
        XCTAssertEqual(installment.number, 2)
        XCTAssertEqual(installment.status, "paid")
    }

}
