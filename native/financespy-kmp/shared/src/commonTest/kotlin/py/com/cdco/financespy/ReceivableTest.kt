package py.com.cdco.financespy

import py.com.cdco.financespy.api.dto.ReceivableDto
import py.com.cdco.financespy.db.ReceivableEntity
import kotlin.test.Test
import kotlin.test.assertEquals

class ReceivableTest {
    @Test
    fun testReceivableDtoToEntityMapping() {
        val dto = ReceivableDto(
            id = "rec-123",
            name = "Préstamo Juan",
            total_amount = 1000.0,
            balance = 400.0,
            balance_cents = 40000L,
            original_balance = 1000.0,
            original_balance_cents = 100000L,
            paid_amount = 600.0,
            paid_amount_cents = 60000L,
            percent_paid = 60.0,
            installment_count = 10,
            due_day = 15,
            currency = "USD",
            notes = "Cuota mensual",
            updated_at = "2026-08-25T12:00:00Z"
        )

        val entity = ReceivableEntity(
            id = dto.id,
            name = dto.name ?: "(sin nombre)",
            totalAmount = dto.total_amount ?: 0.0,
            balance = dto.balance ?: 0.0,
            balanceCents = dto.balance_cents ?: 0L,
            originalBalance = dto.original_balance ?: 0.0,
            originalBalanceCents = dto.original_balance_cents ?: 0L,
            paidAmount = dto.paid_amount ?: 0.0,
            paidAmountCents = dto.paid_amount_cents ?: 0L,
            percentPaid = dto.percent_paid ?: 0.0,
            installmentCount = dto.installment_count,
            dueDay = dto.due_day,
            currency = dto.currency ?: "PYG",
            notes = dto.notes,
            updatedAt = dto.updated_at ?: ""
        )

        assertEquals("rec-123", entity.id)
        assertEquals("Préstamo Juan", entity.name)
        assertEquals(1000.0, entity.totalAmount)
        assertEquals(400.0, entity.balance)
        assertEquals(600.0, entity.paidAmount)
        assertEquals(60.0, entity.percentPaid)
        assertEquals(10, entity.installmentCount)
        assertEquals(15, entity.dueDay)
        assertEquals("USD", entity.currency)
    }
}
