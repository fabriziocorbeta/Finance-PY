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

    @Test
    fun testGnbSmsExtractor() {
        val extractor = GnbSmsExtractor

        // Income case
        val text = "Banco GNB le informa que se registro un Credito en su Cuenta Nro.***  -001: Gs. 930.000 en concepto de Pagos 14/10/2026 19:05:55"
        val purchases = extractor.extract("Banco GNB", text)
        assertEquals(1, purchases.size)
        assertEquals("930000", purchases[0].amount)
        assertEquals("GNB Cuenta Nro.***  -001", purchases[0].cardText)
        assertEquals("Pagos", purchases[0].merchant)
        assertEquals(TransactionNature.INCOME, purchases[0].nature)

        // Invalid case (not matching Credito)
        val nonMatchText = "Banco GNB le informa que se registro un Debito en su Cuenta Nro.***  -001: Gs. 930.000 en concepto de Pagos 14/10/2026 19:05:55"
        val emptyPurchases = extractor.extract("Banco GNB", nonMatchText)
        assertEquals(0, emptyPurchases.size)
    }
}
