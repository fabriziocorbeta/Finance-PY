package py.com.cdco.financespy.sync

import kotlin.test.Test
import kotlin.test.assertEquals

class DateMathTest {
    @Test
    fun ninetyDaysBeforeCrossesYearBoundary() {
        assertEquals("2025-11-20", subtractDays("2026-02-18", 90))
    }

    @Test
    fun handlesLeapYearFebruary() {
        assertEquals("2024-01-30", subtractDays("2024-02-29", 30))
    }

    @Test
    fun zeroDaysReturnsSameDate() {
        assertEquals("2026-08-19", subtractDays("2026-08-19", 0))
    }
}
