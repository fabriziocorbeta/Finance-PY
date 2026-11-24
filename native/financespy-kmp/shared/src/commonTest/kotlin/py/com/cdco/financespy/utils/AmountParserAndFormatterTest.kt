package py.com.cdco.financespy.utils

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class AmountParserAndFormatterTest {
    @Test
    fun parsesParaguayanGuaraniWithThousandsDots() {
        assertEquals("150000", AmountParser.toCanonicalDecimalString("150.000", "PYG"))
        assertEquals(150_000.0, AmountParser.parseToDouble("150.000", "PYG"))
        assertEquals("1250000", AmountParser.toCanonicalDecimalString("1.250.000", "PYG"))
        assertEquals("500000", AmountParser.toCanonicalDecimalString("₲ 500.000", "PYG"))
        assertEquals("72000", AmountParser.toCanonicalDecimalString("Gs. 72.000,00", "PYG"))
    }

    @Test
    fun parsesUsdWithLatAmAndUsSeparators() {
        assertEquals("12.50", AmountParser.toCanonicalDecimalString("12,50", "USD"))
        assertEquals(12.5, AmountParser.parseToDouble("12,50", "USD"))
        assertEquals("1250.50", AmountParser.toCanonicalDecimalString("1.250,50", "USD"))
        assertEquals("1250.50", AmountParser.toCanonicalDecimalString("1,250.50", "USD"))
        assertEquals("0.500", AmountParser.toCanonicalDecimalString("0.500", "USD"))
    }

    @Test
    fun rejectsBlankOrInvalidStrings() {
        assertNull(AmountParser.toCanonicalDecimalString("", "PYG"))
        assertNull(AmountParser.toCanonicalDecimalString("abc", "PYG"))
    }

    @Test
    fun formatMoneyRoundsInsteadOfTruncatingIeee754Doubles() {
        assertEquals("$ 1,15", formatMoney(1.15, "USD"))
        assertEquals("$ 19,99", formatMoney(19.99, "USD"))
        assertEquals("$ 0,29", formatMoney(0.29, "USD"))
        assertEquals("₲ 150.001", formatMoney(150_000.6, "PYG"))
        assertEquals("₲ 1.000.000", formatMoney(1_000_000L, "PYG"))
    }
}
