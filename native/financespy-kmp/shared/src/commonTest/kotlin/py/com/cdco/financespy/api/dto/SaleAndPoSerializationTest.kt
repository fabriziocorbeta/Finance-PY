package py.com.cdco.financespy.api.dto

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
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import py.com.cdco.financespy.api.FinancePyApi
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SaleAndPoSerializationTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun testSaleRequestDtoSerialization() {
        val payload = SaleRequestDto(
            sale = SalePayloadDto(
                client_name = "John Doe",
                currency = "pyg",
                payment_method = "cash",
                account_id = "acc123",
                sale_items_attributes = listOf(
                    SaleItemRequestDto(
                        product_id = "prod1",
                        quantity = 2,
                        unit_price = 15000.0
                    )
                )
            )
        )

        val jsonString = json.encodeToString(payload)

        // Assert matches what Rails expects
        assertTrue(jsonString.contains("\"sale\":{"))
        assertTrue(jsonString.contains("\"client_name\":\"John Doe\""))
        assertTrue(jsonString.contains("\"currency\":\"pyg\""))
        assertTrue(jsonString.contains("\"sale_items_attributes\":[{"))
        assertTrue(jsonString.contains("\"product_id\":\"prod1\""))
    }

    @Test
    fun testPurchaseOrderRequestDtoSerialization() {
        val payload = PurchaseOrderRequestDto(
            purchase_order = PurchaseOrderPayloadDto(
                supplier_name = "Supplier Inc",
                currency = "usd",
                account_id = "acc456",
                purchase_order_items_attributes = listOf(
                    PurchaseOrderItemRequestDto(
                        product_id = "prod2",
                        quantity = 10,
                        unit_cost = 5.0
                    )
                )
            )
        )

        val jsonString = json.encodeToString(payload)

        // Assert matches what Rails expects
        assertTrue(jsonString.contains("\"purchase_order\":{"))
        assertTrue(jsonString.contains("\"supplier_name\":\"Supplier Inc\""))
        assertTrue(jsonString.contains("\"currency\":\"usd\""))
        assertTrue(jsonString.contains("\"purchase_order_items_attributes\":[{"))
        assertTrue(jsonString.contains("\"product_id\":\"prod2\""))
    }

    @Test
    fun testSaleAndPurchaseOrderInvoicePhotoDeserialization() {
        val saleJson = """
            {
              "data": {
                "id": "sale-1",
                "sale_number": 42,
                "status": "completed",
                "currency": "pyg",
                "total": 250000.0,
                "has_invoice_photo": true,
                "invoice_photo": {
                  "filename": "factura_42.jpg",
                  "content_type": "image/jpeg",
                  "byte_size": 123456,
                  "url": "/api/v1/sales/sale-1/invoice_photo"
                },
                "sale_items": []
              }
            }
        """.trimIndent()

        val saleResponse = json.decodeFromString<SaleResponseDto>(saleJson)
        assertTrue(saleResponse.data.has_invoice_photo)
        val salePhoto = assertNotNull(saleResponse.data.invoice_photo)
        assertEquals("factura_42.jpg", salePhoto.filename)
        assertEquals("image/jpeg", salePhoto.content_type)
        assertEquals(123456L, salePhoto.byte_size)
        assertEquals("/api/v1/sales/sale-1/invoice_photo", salePhoto.url)

        val poJson = """
            {
              "data": {
                "id": "po-1",
                "order_number": 7,
                "status": "received",
                "currency": "pyg",
                "total": 500000.0,
                "has_invoice_photo": true,
                "invoice_photo": {
                  "filename": "factura_po_7.pdf",
                  "content_type": "application/pdf",
                  "byte_size": 65432,
                  "url": "/api/v1/purchase_orders/po-1/invoice_photo"
                },
                "purchase_order_items": []
              }
            }
        """.trimIndent()

        val poResponse = json.decodeFromString<PurchaseOrderResponseDto>(poJson)
        assertTrue(poResponse.data.has_invoice_photo)
        val poPhoto = assertNotNull(poResponse.data.invoice_photo)
        assertEquals("factura_po_7.pdf", poPhoto.filename)
        assertEquals("application/pdf", poPhoto.content_type)
        assertEquals(65432L, poPhoto.byte_size)
        assertEquals("/api/v1/purchase_orders/po-1/invoice_photo", poPhoto.url)
    }

    @Test
    fun testFinancePyApiInvoicePhotoEndpoints() = runTest {
        val sampleImageBytes = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xE0.toByte())
        val mockEngine = MockEngine { request ->
            val path = request.url.encodedPath
            when {
                path == "/api/v1/sales/s1/invoice_photo" && request.method == HttpMethod.Post -> {
                    respond(
                        content = """{"data":{"id":"s1","has_invoice_photo":true,"invoice_photo":{"filename":"recibo.jpg","content_type":"image/jpeg","byte_size":4,"url":"/api/v1/sales/s1/invoice_photo"}}}""",
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                    )
                }
                path == "/api/v1/sales/s1/invoice_photo" && request.method == HttpMethod.Delete -> {
                    respond(
                        content = """{"data":{"id":"s1","has_invoice_photo":false,"invoice_photo":null}}""",
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                    )
                }
                path == "/api/v1/sales/s1/invoice_photo" && request.method == HttpMethod.Get -> {
                    respond(
                        content = sampleImageBytes,
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, ContentType.Image.JPEG.toString())
                    )
                }
                path == "/api/v1/purchase_orders/p1/invoice_photo" && request.method == HttpMethod.Post -> {
                    respond(
                        content = """{"data":{"id":"p1","has_invoice_photo":true,"invoice_photo":{"filename":"po.jpg","content_type":"image/jpeg","byte_size":4,"url":"/api/v1/purchase_orders/p1/invoice_photo"}}}""",
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                    )
                }
                path == "/api/v1/purchase_orders/p1/invoice_photo" && request.method == HttpMethod.Delete -> {
                    respond(
                        content = """{"data":{"id":"p1","has_invoice_photo":false,"invoice_photo":null}}""",
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, ContentType.Application.Json.toString())
                    )
                }
                path == "/api/v1/purchase_orders/p1/invoice_photo" && request.method == HttpMethod.Get -> {
                    respond(
                        content = sampleImageBytes,
                        status = HttpStatusCode.OK,
                        headers = headersOf(HttpHeaders.ContentType, ContentType.Image.JPEG.toString())
                    )
                }
                else -> error("Unhandled request: ${request.method.value} $path")
            }
        }

        val client = HttpClient(mockEngine) {
            install(ContentNegotiation) {
                json(Json { ignoreUnknownKeys = true })
            }
        }
        val api = FinancePyApi(client)

        val uploadedSale = api.uploadSaleInvoicePhoto("s1", sampleImageBytes, "recibo.jpg", "image/jpeg")
        assertTrue(uploadedSale.has_invoice_photo)
        assertEquals("recibo.jpg", uploadedSale.invoice_photo?.filename)

        val downloadedSaleBytes = api.downloadSaleInvoicePhoto("s1")
        assertContentEquals(sampleImageBytes, downloadedSaleBytes)

        val deletedSale = api.deleteSaleInvoicePhoto("s1")
        assertFalse(deletedSale.has_invoice_photo)
        assertNull(deletedSale.invoice_photo)

        val uploadedPo = api.uploadPurchaseOrderInvoicePhoto("p1", sampleImageBytes, "po.jpg", "image/jpeg")
        assertTrue(uploadedPo.has_invoice_photo)
        assertEquals("po.jpg", uploadedPo.invoice_photo?.filename)

        val downloadedPoBytes = api.downloadPurchaseOrderInvoicePhoto("p1")
        assertContentEquals(sampleImageBytes, downloadedPoBytes)

        val deletedPo = api.deletePurchaseOrderInvoicePhoto("p1")
        assertFalse(deletedPo.has_invoice_photo)
        assertNull(deletedPo.invoice_photo)
    }
}
