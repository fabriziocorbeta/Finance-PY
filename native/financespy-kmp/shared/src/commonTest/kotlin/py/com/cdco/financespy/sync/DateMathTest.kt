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

    @Test
    fun endOfMonthFebruaryLeapYear() {
        assertEquals("2024-02-29", endOfMonthDate(2024, 2))
    }

    @Test
    fun endOfMonthFebruaryNonLeapYear() {
        assertEquals("2026-02-28", endOfMonthDate(2026, 2))
    }

    @Test
    fun endOfMonthApril30Days() {
        assertEquals("2026-04-30", endOfMonthDate(2026, 4))
    }

    @Test
    fun endOfMonthDecember31Days() {
        assertEquals("2026-12-31", endOfMonthDate(2026, 12))
    }
}
