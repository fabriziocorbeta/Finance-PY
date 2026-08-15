package py.com.cdco.financespy.wallet

data class Purchase(val amount: String, val cardText: String)

object PurchaseExtractor {
    private val PURCHASE_PATTERN = Regex("""PYG([\d,]+) con (.+)""")

    fun extract(notificationText: String): Purchase? {
        val match = PURCHASE_PATTERN.find(notificationText) ?: return null
        val (amount, cardText) = match.destructured
        return Purchase(amount, cardText.trim())
    }
}
