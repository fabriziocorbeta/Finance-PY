import XCTest
@testable import FinancePY

final class FuelLogDtoDecodingTests: XCTestCase {

    func testDecodeFuelLogWithStringAmounts() throws {
        let json = """
        {
            "id": "abc-123",
            "fleet_vehicle_id": "veh-123",
            "account_id": "acc-123",
            "logged_at": "2023-10-01",
            "odometer": 15000.5,
            "liters": "45.50",
            "cost": "10500.00",
            "notes": "Full tank",
            "entry_id": null,
            "created_at": "2023-10-01T10:00:00Z",
            "updated_at": "2023-10-01T10:00:00Z",
            "fuel_log_lines": [
                {
                    "id": "line-123",
                    "fuel_type": "nafta",
                    "brand": "Podium",
                    "liters": "45.50",
                    "cost": "10500.00"
                }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let fuelLog = try decoder.decode(FuelLogDto.self, from: json)

        XCTAssertEqual(fuelLog.liters, "45.50")
        XCTAssertEqual(fuelLog.cost, "10500.00")
        XCTAssertEqual(fuelLog.fuelLogLines?.first?.liters, "45.50")
        XCTAssertEqual(fuelLog.fuelLogLines?.first?.cost, "10500.00")
    }

    func testDecodeFuelLogWithNumberAmounts() throws {
        let json = """
        {
            "id": "abc-123",
            "fleet_vehicle_id": "veh-123",
            "account_id": "acc-123",
            "logged_at": "2023-10-01",
            "odometer": 15000.5,
            "liters": 45.5,
            "cost": 10500.0,
            "notes": "Full tank",
            "entry_id": null,
            "created_at": "2023-10-01T10:00:00Z",
            "updated_at": "2023-10-01T10:00:00Z",
            "fuel_log_lines": [
                {
                    "id": "line-123",
                    "fuel_type": "nafta",
                    "brand": "Podium",
                    "liters": 45.5,
                    "cost": 10500.0
                }
            ]
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let fuelLog = try decoder.decode(FuelLogDto.self, from: json)

        XCTAssertEqual(fuelLog.liters, "45.5")
        XCTAssertEqual(fuelLog.cost, "10500.0")
        XCTAssertEqual(fuelLog.fuelLogLines?.first?.liters, "45.5")
        XCTAssertEqual(fuelLog.fuelLogLines?.first?.cost, "10500.0")
    }

}
