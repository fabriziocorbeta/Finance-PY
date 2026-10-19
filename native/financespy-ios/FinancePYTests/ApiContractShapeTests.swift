import XCTest
@testable import FinancePY

/// Decodes the exact shapes the Rails API emits today.
///
/// Every JSON here is a literal copy of a real response, not a Swift struct
/// encoded and decoded back. That round-trip pattern is what let three
/// separate production bugs through: it only proves a DTO is symmetric with
/// itself, and passes green while the screen is broken.
///
/// The envelope rule these pin down: a collection that returns `data`/`meta`
/// also wraps its single-resource endpoints in `data`. Sales and purchase
/// orders do; accounts and transactions return the object at the root.
final class ApiContractShapeTests: XCTestCase {

    private func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(type, from: Data(json.utf8))
    }

    // GET /api/v1/sales/:id — app/views/api/v1/sales/show.json.jbuilder wraps
    // the resource in `data`. iOS decoded SaleDto at the root and failed with
    // keyNotFound("id") on every sale tapped.
    func testSingleSaleIsWrappedInData() throws {
        // Capturado de producción renderizando api/v1/sales/show con una venta
        // real. Nótese `currency` en minúsculas y `total` numérico.
        let json = """
        {"data":{"id":"8ff0a30c-1443-4dcb-97f3-f9a9b37a2b30","sale_number":3,"client_name":"Camila Amarilla","status":"completed","currency":"pyg","payment_method":"Transferencia","invoice_number":"770","condition":"Contado","notes":"","delivery_address":"","delivery_date":"2026-09-02","carrier":"","account_id":"c82772a4-333f-4408-95f6-296005aa5d8f","total":420000.0,"created_at":"2026-09-02T21:00:28-03:00","updated_at":"2026-09-02T21:00:37-03:00","sale_items":[{"id":"166d359a-74d4-4ccb-ba84-a050c27d30fa","sale_id":"8ff0a30c-1443-4dcb-97f3-f9a9b37a2b30","product_id":"9f0c787e-c4bd-4674-90e1-eae021249798","product_name":"Casio Dama LTP-1165N-9C","product_sku":"LTP-1165N-9C","quantity":1,"unit_price":420000.0,"subtotal":420000.0,"created_at":"2026-09-02T21:00:28-03:00","updated_at":"2026-09-02T21:00:28-03:00"}]}}
        """

        let response = try decode(SaleResponseDto.self, from: json)

        XCTAssertEqual(response.data.id, "8ff0a30c-1443-4dcb-97f3-f9a9b37a2b30")
        XCTAssertEqual(response.data.status, "completed")
        XCTAssertEqual(response.data.saleItems?.count, 1)
    }

    // Same envelope for purchase orders.
    func testSinglePurchaseOrderIsWrappedInData() throws {
        // Capturado de producción renderizando api/v1/purchase_orders/show.
        let json = """
        {"data":{"id":"e95d0084-7107-4247-8643-c28107677773","order_number":1,"supplier_name":"Casa Joia","status":"draft","currency":"usd","expected_date":"2026-09-16","notes":"","account_id":"105cfb3e-0254-4b6e-b8d6-31640ece30d6","total":205.0,"created_at":"2026-09-20T23:58:51-03:00","updated_at":"2026-09-20T23:58:51-03:00","purchase_order_items":[{"id":"9d9c76a5-0175-4dff-8c3a-c895c2f932e0","purchase_order_id":"e95d0084-7107-4247-8643-c28107677773","product_id":"889e0c4d-bfba-40cc-b0e4-1c0982a01a53","product_name":"CASIO DAMA LTP-V007G-9","product_sku":"LTP-V007G-9","quantity":2,"unit_cost":35.0,"subtotal":70.0,"created_at":"2026-09-20T23:58:51-03:00","updated_at":"2026-09-20T23:58:51-03:00"}]}}
        """

        let response = try decode(PurchaseOrderResponseDto.self, from: json)

        XCTAssertEqual(response.data.orderNumber, 1)
        XCTAssertEqual(response.data.status, "draft")
        XCTAssertEqual(response.data.purchaseOrderItems?.count, 1)
    }

    // Goal#months_remaining is `days / 30.0` and Goal#pace is a BigDecimal, so
    // both arrive as JSON numbers. The real production goal has
    // months_remaining = 11.366666666666667, which an Int? rejects outright --
    // that single field failing takes the whole Goals screen down.
    func testGoalAcceptsFractionalMonthsAndNumericPace() throws {
        let json = """
        {"id":"c1000000-0000-4000-8000-000000000001","name":"Fondo de emergencia","target_amount":"50000000.0","target_date":"2027-10-05","currency":"PYG","progress_basis":"balance","current_balance":"5000000.0","current_balance_cents":500000000,"remaining_amount":"45000000.0","remaining_amount_cents":4500000000,"progress_percent":10,"pace":3951948.33,"status":"on_track","months_remaining":11.366666666666667,"catch_up_delta":"0.0","account_ids":[],"allocations":{}}
        """

        let goal = try decode(GoalDto.self, from: json)

        XCTAssertEqual(goal.monthsRemaining ?? 0, 11.366666666666667, accuracy: 0.0001)
        XCTAssertEqual(goal.pace, "3951948.33")
    }

    // A goal with no target_date has no months_remaining at all.
    func testGoalWithoutTargetDateDecodes() throws {
        let json = """
        {"id":"c1000000-0000-4000-8000-000000000002","name":"Sin fecha","target_amount":"1000000.0","target_date":null,"currency":"PYG","progress_basis":"balance","current_balance":"0.0","current_balance_cents":0,"remaining_amount":"1000000.0","remaining_amount_cents":100000000,"progress_percent":0,"pace":0,"status":"on_track","months_remaining":null,"catch_up_delta":"0.0","account_ids":[],"allocations":{}}
        """

        let goal = try decode(GoalDto.self, from: json)

        XCTAssertNil(goal.monthsRemaining)
    }

    // The counter-case, so these tests pin the actual rule rather than
    // "everything is wrapped": accounts return the object at the root.
    //
    // The payload includes card_identifier, which AccountDto does not declare
    // yet (that field landed in #555 and the iOS side is a follow-up). This
    // asserts the decode tolerates it: Swift ignores unknown keys, so an added
    // backend field must not break existing clients.
    func testSingleAccountIsNotWrappedAndToleratesNewBackendFields() throws {
        let json = """
        {"id":"a1000000-0000-4000-8000-000000000001","name":"Amex Gold","balance":"3.734.560 ₲","balance_cents":373456000,"cash_balance":"0 ₲","cash_balance_cents":0,"currency":"PYG","classification":"liability","account_type":"credit_card","subtype":null,"status":"active","institution_name":null,"institution_domain":null,"card_identifier":"2269","created_at":"2026-07-03T12:00:00Z","updated_at":"2026-10-19T12:00:00Z"}
        """

        let account = try decode(AccountDto.self, from: json)

        XCTAssertEqual(account.name, "Amex Gold")
    }
}
