package py.com.cdco.financespy

import kotlinx.serialization.json.Json
import py.com.cdco.financespy.api.dto.GoalDto
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

// Reproduce el crash real reportado en producción: una meta con una cuenta
// vinculada sin monto fijo asignado (allocation tipo "pool", diseño intencional
// del modelo Goal -- allocated_amount es opcional) serializa esa entrada como
// `null` en el JSON. Antes del fix, GoalDto.allocations era
// Map<String, String>? (mapa nullable, pero valores no-nullable) -- un solo
// `null` en el mapa rompía kotlinx.serialization con
// "Unexpected 'null' value instead of string literal" y tiraba abajo el
// parseo de TODA la lista de metas, no solo esa entrada.
class GoalDtoTest {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }

    @Test
    fun parsesAllocationsWithNullValue() {
        val raw = """
            {
                "id": "goal-1",
                "name": "Fondo de emergencia",
                "allocations": {
                    "account-a": "500000",
                    "account-b": null
                }
            }
        """.trimIndent()

        val goal = json.decodeFromString(GoalDto.serializer(), raw)

        assertEquals("500000", goal.allocations?.get("account-a"))
        assertNull(goal.allocations?.get("account-b"))
    }

    @Test
    fun parsesAllocationsAllNull() {
        val raw = """
            {
                "id": "goal-2",
                "name": "Meta sin montos fijos",
                "allocations": {
                    "account-a": null,
                    "account-b": null
                }
            }
        """.trimIndent()

        val goal = json.decodeFromString(GoalDto.serializer(), raw)

        assertEquals(2, goal.allocations?.size)
        assertNull(goal.allocations?.get("account-a"))
        assertNull(goal.allocations?.get("account-b"))
    }

    @Test
    fun parsesGoalWithoutAllocationsField() {
        val raw = """{"id": "goal-3", "name": "Meta sin cuentas vinculadas"}"""

        val goal = json.decodeFromString(GoalDto.serializer(), raw)

        assertNull(goal.allocations)
    }
}
