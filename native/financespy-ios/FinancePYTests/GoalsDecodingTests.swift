import XCTest
@testable import FinancePY

final class GoalsDecodingTests: XCTestCase {

    func testGoalDecodingToleratesNumbersAndStrings() throws {
        let json = """
        {
            "data": {
                "id": "goal_123",
                "name": "Vacation Fund",
                "target_amount": "5000.0",
                "currency": "USD",
                "target_date": "2024-12-31",
                "color": "#FF0000",
                "icon": "airplane",
                "notes": "Trip to Japan",
                "state": "active",
                "progress_basis": "balance",
                "current_balance": 1500.5,
                "current_balance_cents": 150050,
                "remaining_amount": "3499.5",
                "remaining_amount_cents": 349950,
                "progress_percent": 30,
                "account_ids": ["acc_1", "acc_2"],
                "pace": "on_track",
                "status": "on_track",
                "months_remaining": 10,
                "catch_up_delta": 50.0,
                "allocations": {
                    "acc_1": "1000.0",
                    "acc_2": "500.5"
                }
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(GoalSingleResponse.self, from: json)
        let goal = response.data

        XCTAssertEqual(goal.id, "goal_123")
        XCTAssertEqual(goal.name, "Vacation Fund")
        XCTAssertEqual(goal.targetAmount, "5000.0") // String from backend
        XCTAssertEqual(goal.currency, "USD")
        XCTAssertEqual(goal.currentBalance, "1500.5") // Number from backend parsed into string wrapper
        XCTAssertEqual(goal.currentBalanceCents, 150050)
        XCTAssertEqual(goal.remainingAmount, "3499.5") // String from backend
        XCTAssertEqual(goal.catchUpDelta, "50.0") // Number from backend parsed into string wrapper
        XCTAssertEqual(goal.accountIds, ["acc_1", "acc_2"])
    }

    func testGoalPledgeDecoding() throws {
        let json = """
        {
            "data": [
                {
                    "id": "pledge_1",
                    "goal_id": "goal_123",
                    "account_id": "acc_1",
                    "amount": "100.0",
                    "currency": "USD",
                    "kind": "monthly",
                    "status": "open",
                    "expires_at": "2024-03-01T00:00:00Z",
                    "days_left": 15,
                    "account_name": "Checking"
                }
            ],
            "meta": {
                "current_page": 1,
                "next_page": null,
                "prev_page": null,
                "total_pages": 1,
                "total_count": 1,
                "per_page": 25
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(GoalPledgesResponse.self, from: json)

        XCTAssertEqual(response.data.count, 1)
        let pledge = response.data.first!

        XCTAssertEqual(pledge.id, "pledge_1")
        XCTAssertEqual(pledge.goalId, "goal_123")
        XCTAssertEqual(pledge.accountId, "acc_1")
        XCTAssertEqual(pledge.amount, "100.0")
        XCTAssertEqual(pledge.currency, "USD")
        XCTAssertEqual(pledge.status, "open")
        XCTAssertEqual(pledge.daysLeft, 15)
        XCTAssertEqual(pledge.accountName, "Checking")

        XCTAssertEqual(response.meta?.currentPage, 1)
        XCTAssertEqual(response.meta?.totalCount, 1)
    }
}
