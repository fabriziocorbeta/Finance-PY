package py.com.cdco.financespy.wallet

import org.junit.Assert.assertEquals
import org.junit.Test

class PurchaseExtractorTest {
    @Test
    fun testWalletTapExtractor() {
        val extractor = WalletTapExtractor

        // original case
        var purchases = extractor.extract("Super6", "PYG150,000 con MiTarjeta")
        assertEquals(1, purchases.size)
        assertEquals("150000", purchases[0].amount) // Note: Amount is now clean of commas
        assertEquals("MiTarjeta", purchases[0].cardText)
        assertEquals("Super6", purchases[0].merchant)

        // new case 1: with dot
        purchases = extractor.extract("Super6", "PYG 150.000 con MiTarjeta")
        assertEquals(1, purchases.size)
        assertEquals("150000", purchases[0].amount)
        assertEquals("MiTarjeta", purchases[0].cardText)
        assertEquals("Super6", purchases[0].merchant)

        // new case 2: no separator, space
        purchases = extractor.extract("Super6", "PYG 150000 con MiTarjeta")
        assertEquals(1, purchases.size)
        assertEquals("150000", purchases[0].amount)
    }
}
