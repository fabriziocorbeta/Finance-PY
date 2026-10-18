import XCTest
@testable import FinancePY

final class DecodingTests: XCTestCase {

    override func setUp() {
        super.setUp()
    }

    func testProductIndexPaginationDecode() throws {
        let json = """
        {
          "data": [],
          "meta": {
            "current_page": 1,
            "next_page": null,
            "prev_page": null,
            "total_pages": 1,
            "total_count": 0,
            "per_page": 100
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(ProductsResponseDto.self, from: json)
        XCTAssertEqual(response.meta?.currentPage, 1)
        XCTAssertNil(response.meta?.nextPage)
        XCTAssertEqual(response.meta?.totalCount, 0)
    }

    // Contract test for PR #542: API v1 has two list envelope conventions:
    // 1) `meta` envelopes (budgets, products, goals) send `current_page`
    // 2) `pagination` envelopes (accounts, transactions, chats) send `page`
    // Both use non-1 page numbers (3 and 2) so that if someone removes either key
    // from PaginationDto.init(from:), the `?? 1` fallback cannot mask the regression.
    func testPaginationDtoDecodesMetaEnvelopeWithCurrentPage() throws {
        let metaEnvelopeJson = """
        {
          "data": [],
          "meta": {
            "current_page": 3,
            "next_page": 4,
            "prev_page": 2,
            "total_pages": 5,
            "total_count": 120,
            "per_page": 25
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let productsResponse = try decoder.decode(ProductsResponseDto.self, from: metaEnvelopeJson)
        let meta = try XCTUnwrap(productsResponse.meta)
        XCTAssertEqual(meta.currentPage, 3)
        XCTAssertEqual(meta.nextPage, 4)
        XCTAssertEqual(meta.prevPage, 2)
        XCTAssertEqual(meta.totalPages, 5)
        XCTAssertEqual(meta.totalCount, 120)
        XCTAssertEqual(meta.perPage, 25)

        let budgetsResponse = try decoder.decode(BudgetListResponse.self, from: metaEnvelopeJson)
        XCTAssertEqual(budgetsResponse.meta?.currentPage, 3)

        let goalsResponse = try decoder.decode(GoalsResponse.self, from: metaEnvelopeJson)
        XCTAssertEqual(goalsResponse.meta?.currentPage, 3)
    }

    func testPaginationDtoDecodesPaginationEnvelopeWithPage() throws {
        let paginationEnvelopeJson = """
        {
          "accounts": [],
          "transactions": [],
          "chats": [],
          "pagination": {
            "page": 2,
            "next_page": 3,
            "prev_page": 1,
            "total_pages": 4,
            "total_count": 80,
            "per_page": 20
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let accountsResponse = try decoder.decode(AccountsResponse.self, from: paginationEnvelopeJson)
        XCTAssertEqual(accountsResponse.pagination.currentPage, 2)
        XCTAssertEqual(accountsResponse.pagination.nextPage, 3)
        XCTAssertEqual(accountsResponse.pagination.prevPage, 1)
        XCTAssertEqual(accountsResponse.pagination.totalPages, 4)
        XCTAssertEqual(accountsResponse.pagination.totalCount, 80)
        XCTAssertEqual(accountsResponse.pagination.perPage, 20)

        let transactionsResponse = try decoder.decode(TransactionsResponse.self, from: paginationEnvelopeJson)
        XCTAssertEqual(transactionsResponse.pagination.currentPage, 2)

        let chatsResponse = try decoder.decode(ChatsListResponse.self, from: paginationEnvelopeJson)
        XCTAssertEqual(chatsResponse.pagination.currentPage, 2)
    }

    func testBudgetShowDecode() throws {
        let json = """
        {
          "data": {
            "id": "abc-123",
            "start_date": "2024-01-01",
            "end_date": "2024-01-31",
            "currency": "PYG",
            "budgeted_spending": 50000.0,
            "expected_income": 100000.0,
            "name": "January Budget",
            "param": "2024-01",
            "initialized": true,
            "current": true,
            "previous_budget_param": null,
            "next_budget_param": "2024-02",
            "allocations_valid": true,
            "actual_spending": 15000.0,
            "actual_spending_cents": 1500000,
            "available_to_spend": 35000.0,
            "available_to_spend_cents": 3500000,
            "allocated_spending": 50000.0,
            "allocated_spending_cents": 5000000,
            "allocated_percent": 100.0,
            "available_to_allocate": 50000.0,
            "available_to_allocate_cents": 5000000,
            "percent_of_budget_spent": 30.0,
            "actual_income": 100000.0,
            "actual_income_cents": 10000000,
            "actual_income_percent": 100.0,
            "remaining_expected_income": 0.0,
            "remaining_expected_income_cents": 0,
            "surplus_percent": 50.0,
            "donut_segments": [
              { "color": "var(--budget-unallocated-fill)", "amount": 1, "id": "unused" }
            ],
            "categories": []
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(BudgetResponseDto.self, from: json)
        XCTAssertEqual(response.data.id, "abc-123")
        XCTAssertEqual(response.data.donutSegments?.first?.id, "unused")
        XCTAssertNil(response.data.donutSegments?.first?.label) // Without label
    }

    func testRuleShowDecode() throws {
        let json = """
        {
          "data": {
            "id": "rule-1",
            "name": "My Rule",
            "resource_type": "transaction",
            "active": true,
            "effective_date": "2024-01-01",
            "conditions": [
              {
                "id": "cond-1",
                "condition_type": "amount",
                "operator": "gt",
                "value": "100"
              },
              {
                "id": "cond-2",
                "condition_type": "compound",
                "operator": null,
                "sub_conditions": [
                  {
                    "id": "sub-1",
                    "condition_type": "category_id",
                    "operator": "eq",
                    "value": "cat-1"
                  }
                ]
              }
            ],
            "actions": [
              {
                "id": "act-1",
                "action_type": "set_category",
                "value": "cat-2"
              }
            ],
            "created_at": "2024-01-01T00:00:00Z",
            "updated_at": "2024-01-01T00:00:00Z"
          }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(RuleResponseDto.self, from: json)
        let rule = response.data
        XCTAssertEqual(rule.id, "rule-1")
        XCTAssertEqual(rule.conditions.count, 2)
        XCTAssertEqual(rule.conditions[0].conditionType, "amount")
        XCTAssertEqual(rule.conditions[0].operatorStr, "gt")

        XCTAssertEqual(rule.conditions[1].conditionType, "compound")
        XCTAssertNil(rule.conditions[1].operatorStr)
        XCTAssertEqual(rule.conditions[1].subConditions?.first?.conditionType, "category_id")

        XCTAssertEqual(rule.actions.count, 1)
        XCTAssertEqual(rule.actions[0].actionType, "set_category")
    }
}
