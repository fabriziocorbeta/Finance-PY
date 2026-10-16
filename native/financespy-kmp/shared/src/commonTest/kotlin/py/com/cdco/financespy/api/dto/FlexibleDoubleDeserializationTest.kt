package py.com.cdco.financespy.api.dto

import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals

class FlexibleDoubleDeserializationTest {

    private val json = Json { ignoreUnknownKeys = true }

    @Test
    fun testFuelLogDtoDeserialization() {
        val jsonStringNum = """{
            "id": "1",
            "fleet_vehicle_id": "v1",
            "account_id": "a1",
            "logged_at": "2023-10-01",
            "liters": 15.5,
            "cost": 75000.0
        }"""

        val jsonStringStr = """{
            "id": "2",
            "fleet_vehicle_id": "v1",
            "account_id": "a1",
            "logged_at": "2023-10-01",
            "liters": "15.5",
            "cost": "75000.0"
        }"""

        val dtoNum = json.decodeFromString<FuelLogDto>(jsonStringNum)
        assertEquals(15.5, dtoNum.liters)
        assertEquals(75000.0, dtoNum.cost)

        val dtoStr = json.decodeFromString<FuelLogDto>(jsonStringStr)
        assertEquals(15.5, dtoStr.liters)
        assertEquals(75000.0, dtoStr.cost)
    }

    @Test
    fun testInstallmentDtoDeserialization() {
        val jsonStringNum = """{
            "number": 1,
            "due_date": "2023-11-01",
            "amount": 100.5,
            "paid_amount": 50.25,
            "status": "partial"
        }"""

        val jsonStringStr = """{
            "number": 2,
            "due_date": "2023-12-01",
            "amount": "100.5",
            "paid_amount": "50.25",
            "status": "partial"
        }"""

        val dtoNum = json.decodeFromString<InstallmentDto>(jsonStringNum)
        assertEquals(100.5, dtoNum.amount)
        assertEquals(50.25, dtoNum.paid_amount)

        val dtoStr = json.decodeFromString<InstallmentDto>(jsonStringStr)
        assertEquals(100.5, dtoStr.amount)
        assertEquals(50.25, dtoStr.paid_amount)
    }

    @Test
    fun testBudgetDonutSegmentDtoDeserialization() {
        val jsonStringNum = """{
            "id": "1",
            "color": "#FFFFFF",
            "amount": 250.75
        }"""

        val jsonStringStr = """{
            "id": "2",
            "color": "#000000",
            "amount": "250.75"
        }"""

        val dtoNum = json.decodeFromString<BudgetDonutSegmentDto>(jsonStringNum)
        assertEquals(250.75, dtoNum.amount)

        val dtoStr = json.decodeFromString<BudgetDonutSegmentDto>(jsonStringStr)
        assertEquals(250.75, dtoStr.amount)
    }
}