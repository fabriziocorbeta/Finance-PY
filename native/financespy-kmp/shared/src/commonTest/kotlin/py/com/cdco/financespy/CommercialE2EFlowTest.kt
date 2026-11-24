package py.com.cdco.financespy

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.http.ContentType
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.serialization.kotlinx.json.json
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.CreateAccountBody
import py.com.cdco.financespy.api.dto.CreateTransactionBody
import py.com.cdco.financespy.api.dto.ProductDto
import py.com.cdco.financespy.api.dto.SaleItemRequestDto
import py.com.cdco.financespy.api.dto.SalePayloadDto
import py.com.cdco.financespy.api.dto.SaleRequestDto
import py.com.cdco.financespy.utils.formatMoney
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * End-to-end cross-stack contract test for the critical commercial journey:
 * Create wallet -> Record income & expense (PYG) -> Create product & complete sale ->
 * Fetch recalculated budget -> Fetch dashboard (widget source) ->
 * Fetch reports summary & export CSV -> Create & download family ZIP export.
 */
class CommercialE2EFlowTest {
    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = false
    }

    private val jsonHeaders = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString())

    @Test
    fun fullCommercialLifecycleMatchesRailsApiV1Contracts() = runTest {
        val visitedRoutes = mutableListOf<String>()
        val dashboardCache = FakeDashboardCache()

        val engine = MockEngine { request ->
            val route = "${request.method.value} ${request.url.encodedPath}"
            visitedRoutes += route

            when {
                request.method == HttpMethod.Post && request.url.encodedPath == "/api/v1/accounts" -> {
                    respond(
                        content = """
                            {
                              "id": "acc-pyg-1",
                              "name": "Billetera Guaraníes",
                              "balance_cents": 1000000,
                              "cash_balance_cents": 1000000,
                              "currency": "PYG",
                              "classification": "asset",
                              "account_type": "depository",
                              "subtype": "checking",
                              "status": "active",
                              "updated_at": "2026-11-23T10:00:00-03:00"
                            }
                        """.trimIndent(),
                        status = HttpStatusCode.Created,
                        headers = jsonHeaders
                    )
                }

                request.method == HttpMethod.Post && request.url.encodedPath == "/api/v1/transactions" -> {
                    val isIncome = visitedRoutes.count { it == "POST /api/v1/transactions" } == 1
                    val txId = if (isIncome) "tx-income-1" else "tx-expense-1"
                    val amount = if (isIncome) "500000" else "150000"
                    val cents = if (isIncome) 500000L else 150000L
                    val signedCents = if (isIncome) -500000L else 150000L
                    val classification = if (isIncome) "income" else "expense"
                    val name = if (isIncome) "Cobro Honorarios" else "Superseis"

                    respond(
                        content = """
                            {
                              "id": "$txId",
                              "date": "2026-11-23",
                              "amount": "$amount",
                              "amount_cents": $cents,
                              "signed_amount_cents": $signedCents,
                              "currency": "PYG",
                              "name": "$name",
                              "classification": "$classification",
                              "account": { "id": "acc-pyg-1", "name": "Billetera Guaraníes", "account_type": "depository" },
                              "created_at": "2026-11-23T10:05:00-03:00",
                              "updated_at": "2026-11-23T10:05:00-03:00"
                            }
                        """.trimIndent(),
                        status = HttpStatusCode.Created,
                        headers = jsonHeaders
                    )
                }

                request.method == HttpMethod.Post && request.url.encodedPath == "/api/v1/products" -> {
                    respond(
                        content = """
                            {
                              "data": {
                                "id": "prod-1",
                                "name": "Yerba Mate 1kg",
                                "sku": "YM-001",
                                "buy_price": 15000.0,
                                "sell_price": 25000.0,
                                "currency": "pyg",
                                "stock": 10,
                                "min_stock": 2
                              }
                            }
                        """.trimIndent(),
                        status = HttpStatusCode.Created,
                        headers = jsonHeaders
                    )
                }

                request.method == HttpMethod.Post && request.url.encodedPath == "/api/v1/sales" -> {
                    respond(
                        content = """
                            {
                              "data": {
                                "id": "sale-1",
                                "sale_number": 1,
                                "client_name": "Cliente Comercial SA",
                                "status": "draft",
                                "currency": "pyg",
                                "account_id": "acc-pyg-1",
                                "total": 50000.0,
                                "has_invoice_photo": false,
                                "sale_items": [
                                  {
                                    "id": "si-1",
                                    "product_id": "prod-1",
                                    "product_name": "Yerba Mate 1kg",
                                    "quantity": 2,
                                    "unit_price": 25000.0,
                                    "subtotal": 50000.0
                                  }
                                ]
                              }
                            }
                        """.trimIndent(),
                        status = HttpStatusCode.Created,
                        headers = jsonHeaders
                    )
                }

                request.method == HttpMethod.Post && request.url.encodedPath == "/api/v1/sales/sale-1/complete" -> {
                    respond(
                        content = """
                            {
                              "data": {
                                "id": "sale-1",
                                "sale_number": 1,
                                "client_name": "Cliente Comercial SA",
                                "status": "completed",
                                "currency": "pyg",
                                "account_id": "acc-pyg-1",
                                "total": 50000.0,
                                "has_invoice_photo": false,
                                "sale_items": [
                                  {
                                    "id": "si-1",
                                    "product_id": "prod-1",
                                    "product_name": "Yerba Mate 1kg",
                                    "quantity": 2,
                                    "unit_price": 25000.0,
                                    "subtotal": 50000.0
                                  }
                                ]
                              }
                            }
                        """.trimIndent(),
                        status = HttpStatusCode.OK,
                        headers = jsonHeaders
                    )
                }

                request.method == HttpMethod.Get && request.url.encodedPath == "/api/v1/budgets" -> {
                    respond(
                        content = """
                            {
                              "data": [
                                {
                                  "id": "bud-2026-11",
                                  "name": "Noviembre 2026",
                                  "param": "nov-2026",
                                  "start_date": "2026-11-01",
                                  "end_date": "2026-11-30",
                                  "currency": "PYG",
                                  "initialized": true,
                                  "current": true,
                                  "budgeted_spending": 1000000.0,
                                  "actual_spending": 150000.0,
                                  "actual_spending_cents": 150000,
                                  "available_to_spend": 850000.0,
                                  "available_to_spend_cents": 850000,
                                  "percent_of_budget_spent": 15.0
                                }
                              ],
                              "meta": {
                                "current_page": 1,
                                "next_page": null,
                                "prev_page": null,
                                "total_pages": 1,
                                "total_count": 1,
                                "per_page": 100
                              }
                            }
                        """.trimIndent(),
                        status = HttpStatusCode.OK,
                        headers = jsonHeaders
                    )
                }

                request.method == HttpMethod.Get && request.url.encodedPath == "/api/v1/dashboard" -> {
                    val rawDashboard = """
                        {
                          "greeting_name": "Comercial",
                          "currency": "PYG",
                          "period": { "key": "this_month", "label": "Noviembre 2026" },
                          "net_worth": {
                            "amount": 1400000.0,
                            "amount_cents": 1400000,
                            "currency": "PYG",
                            "series": []
                          },
                          "cashflow_sankey": {
                            "currency_symbol": "₲",
                            "nodes": [],
                            "links": []
                          },
                          "outflows_donut": {
                            "currency": "PYG",
                            "currency_symbol": "₲",
                            "total": 150000.0,
                            "categories": [
                              {
                                "id": "cat-super",
                                "name": "Supermercado",
                                "amount": 150000.0,
                                "currency": "PYG",
                                "percentage": 100.0,
                                "color": "#10b981",
                                "clickable": true
                              }
                            ]
                          },
                          "balance_sheet": {
                            "classification_groups": [
                              {
                                "classification": "asset",
                                "name": "Activos",
                                "icon": "wallet",
                                "total": 1400000.0,
                                "total_cents": 1400000,
                                "account_groups": [
                                  {
                                    "key": "depository",
                                    "name": "Efectivo y Bancos",
                                    "color": "#16A34A",
                                    "weight": 100.0,
                                    "total": 1400000.0,
                                    "total_cents": 1400000,
                                    "accounts": [
                                      {
                                        "id": "acc-pyg-1",
                                        "name": "Billetera Guaraníes",
                                        "balance": 1400000.0,
                                        "balance_cents": 1400000,
                                        "currency": "PYG"
                                      }
                                    ]
                                  }
                                ]
                              }
                            ]
                          },
                          "investment_summary": null
                        }
                    """.trimIndent()
                    dashboardCache.save("this_month", rawDashboard)
                    respond(content = rawDashboard, status = HttpStatusCode.OK, headers = jsonHeaders)
                }

                request.method == HttpMethod.Get && request.url.encodedPath == "/api/v1/reports/export_transactions" -> {
                    respond(
                        content = "Category,Nov 2026,Total\nEXPENSES,,\nSupermercado,₲ 150.000,₲ 150.000\n",
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, "text/csv")
                    )
                }

                request.method == HttpMethod.Post && request.url.encodedPath == "/api/v1/family_exports" -> {
                    respond(
                        content = """
                            {
                              "data": {
                                "id": "exp-1",
                                "status": "completed",
                                "filename": "financepy_export.zip",
                                "downloadable": true,
                                "download_path": "/api/v1/family_exports/exp-1/download",
                                "file": { "attached": true, "byte_size": 128, "content_type": "application/zip" },
                                "created_at": "2026-11-23T10:10:00-03:00"
                              }
                            }
                        """.trimIndent(),
                        status = HttpStatusCode.Accepted,
                        headers = jsonHeaders
                    )
                }

                request.method == HttpMethod.Get && request.url.encodedPath == "/api/v1/family_exports/exp-1/download" -> {
                    respond(
                        content = "PK\u0003\u0004mock-zip",
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, "application/zip")
                    )
                }

                else -> error("Unexpected API call: $route")
            }
        }

        val httpClient = HttpClient(engine) {
            expectSuccess = true
            install(ContentNegotiation) { json(json) }
        }
        val api = FinancePyApi(httpClient)

        // 1. Crear cuenta/billetera PYG
        val account = api.createAccount(
            CreateAccountBody(
                accountable_type = "Depository",
                name = "Billetera Guaraníes",
                balance = 1_000_000.0,
                currency = "PYG"
            )
        )
        assertEquals("acc-pyg-1", account.id)
        assertEquals(1_000_000L, account.balance_cents)
        assertEquals("₲ 1.000.000", formatMoney(account.balance_cents, account.currency))

        // 2. Registrar ingreso y gasto
        val income = api.createTransaction(
            CreateTransactionBody(
                account_id = account.id,
                date = "2026-11-23",
                amount = "500000",
                nature = "income",
                name = "Cobro Honorarios",
                currency = "PYG"
            )
        )
        assertEquals("income", income.classification)
        assertEquals(-500_000L, income.signed_amount_cents)

        val expense = api.createTransaction(
            CreateTransactionBody(
                account_id = account.id,
                date = "2026-11-23",
                amount = "150000",
                nature = "expense",
                name = "Superseis",
                currency = "PYG"
            )
        )
        assertEquals("expense", expense.classification)
        assertEquals(150_000L, expense.signed_amount_cents)

        // 3. Crear producto y completar venta
        val product = api.createProduct(
            ProductDto(
                id = "",
                name = "Yerba Mate 1kg",
                sku = "YM-001",
                buy_price = 15_000.0,
                sell_price = 25_000.0,
                currency = "pyg",
                stock = 10,
                min_stock = 2
            )
        )
        val draftSale = api.createSale(
            SaleRequestDto(
                sale = SalePayloadDto(
                    client_name = "Cliente Comercial SA",
                    currency = "pyg",
                    account_id = account.id,
                    sale_items_attributes = listOf(
                        SaleItemRequestDto(product_id = product.id, quantity = 2, unit_price = 25_000.0)
                    )
                )
            )
        )
        assertEquals("draft", draftSale.status)
        val completedSale = api.completeSale(draftSale.id)
        assertEquals("completed", completedSale.status)
        assertEquals(50_000.0, completedSale.total)

        // 4. Consultar presupuesto recalculado
        val budgets = api.fetchAllBudgets()
        assertEquals(1, budgets.size)
        assertEquals(150_000L, budgets.first().actual_spending_cents)
        assertEquals(850_000L, budgets.first().available_to_spend_cents)

        // 5. Consultar dashboard (fuente de datos de los widgets nativos)
        val dashboard = api.fetchDashboard(period = "this_month")
        assertEquals("PYG", dashboard.currency)
        assertEquals(1_400_000L, dashboard.net_worth?.amount_cents)
        assertEquals(150_000.0, dashboard.outflows_donut?.total)
        assertTrue(dashboardCache.load("this_month")?.contains("1400000") == true)

        // 6. Exportar transacciones CSV y exportación completa ZIP de familia
        val csvBytes = api.exportTransactionsCsv(periodType = "monthly")
        assertTrue(csvBytes.decodeToString().contains("Supermercado"))

        val export = api.createFamilyExport()
        assertEquals("completed", export.status)
        assertTrue(export.downloadable)

        val zipBytes = api.downloadFamilyExport(export.id)
        assertTrue(zipBytes.decodeToString().startsWith("PK"))

        assertEquals(
            listOf(
                "POST /api/v1/accounts",
                "POST /api/v1/transactions",
                "POST /api/v1/transactions",
                "POST /api/v1/products",
                "POST /api/v1/sales",
                "POST /api/v1/sales/sale-1/complete",
                "GET /api/v1/budgets",
                "GET /api/v1/dashboard",
                "GET /api/v1/reports/export_transactions",
                "POST /api/v1/family_exports",
                "GET /api/v1/family_exports/exp-1/download"
            ),
            visitedRoutes
        )
    }
}
