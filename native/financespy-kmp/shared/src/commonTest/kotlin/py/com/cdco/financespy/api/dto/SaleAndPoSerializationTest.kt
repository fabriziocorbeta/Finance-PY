package py.com.cdco.financespy.api.dto

import kotlinx.serialization.json.Json
import kotlinx.serialization.encodeToString
import kotlin.test.Test
import kotlin.test.assertEquals
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
}
