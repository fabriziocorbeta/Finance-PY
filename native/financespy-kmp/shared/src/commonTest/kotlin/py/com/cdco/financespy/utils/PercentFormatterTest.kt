package py.com.cdco.financespy.utils

import kotlin.test.Test
import kotlin.test.assertEquals

class PercentFormatterTest {

    @Test
    fun formatsNullReturnsEmptyString() {
        assertEquals("", formatPercent(null))
    }

    @Test
    fun formatsZeroPercent() {
        assertEquals("0.0%", formatPercent(0.0))
    }

    @Test
    fun formatsPositiveFloatValueToOneDecimal() {
        assertEquals("12.8%", formatPercent(12.847293847))
        assertEquals("12.9%", formatPercent(12.86))
        assertEquals("12.0%", formatPercent(12.0))
    }

    @Test
    fun formatsNegativeFloatValueToOneDecimal() {
        assertEquals("-5.5%", formatPercent(-5.46))
        assertEquals("-0.5%", formatPercent(-0.54))
    }

    @Test
    fun formatsWithCustomDecimals() {
        assertEquals("12.85%", formatPercent(12.847293847, decimals = 2))
        assertEquals("13%", formatPercent(12.847293847, decimals = 0))
    }
}
