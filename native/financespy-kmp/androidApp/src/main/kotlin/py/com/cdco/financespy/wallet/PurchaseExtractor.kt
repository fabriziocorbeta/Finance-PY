package py.com.cdco.financespy.wallet

data class Purchase(val amount: String, val cardText: String, val merchant: String)

interface BankNotificationExtractor {
    fun extract(title: String, text: String): Purchase?
}

// Google Wallet NFC tap-to-pay. Notification title IS the merchant name
// here (Wallet doesn't echo it in the body), text is "PYG<amount> con
// <card>". Amount comes comma-grouped ("150,000") -- WebhookClient already
// strips commas before posting, so left as-is.
object WalletTapExtractor : BankNotificationExtractor {
    private val PATTERN = Regex("""PYG([\d,]+) con (.+)""")

    override fun extract(title: String, text: String): Purchase? {
        val match = PATTERN.find(text) ?: return null
        val (amount, cardText) = match.destructured
        return Purchase(amount, cardText.trim(), merchant = title)
    }
}

// ueno bank (py.com.elcomercio.retailbanking). Real notification pair:
//   title: "Pagaste en GOOGLE *YouTube        LONDON        GBR"
//   text:  "Usaste tu tarjeta Mastercard *2601 para pagar Gs. 62.527 el dia 08-10-2026 22:34:15"
// Only "Pagaste en ..." notifications are purchases; reintegro/cashback ones
// ("¡Te reintegramos Gs. X!") don't match TITLE_PATTERN and are silently
// skipped -- they're not an expense, counting them would double them up
// against the purchase that earned the cashback.
object UenoBankExtractor : BankNotificationExtractor {
    private val TITLE_PATTERN = Regex("""^Pagaste en\s+(.+)$""")
    private val TEXT_PATTERN = Regex("""Usaste tu tarjeta (.+?) para pagar Gs\.\s*([\d.]+)""")

    override fun extract(title: String, text: String): Purchase? {
        val merchantMatch = TITLE_PATTERN.find(title.trim()) ?: return null
        val textMatch = TEXT_PATTERN.find(text) ?: return null
        val (cardText, rawAmount) = textMatch.destructured
        val merchant = merchantMatch.groupValues[1].trim().replace(Regex("\\s{2,}"), " ")
        // Gs. amounts use '.' as the thousands separator, not a decimal
        // point ("62.527" is 62,527 Gs, not 62.527) -- strip it so the
        // backend's BigDecimal parse doesn't read it as fractional Guaraníes.
        //
        // ueno's own notification text never says "Ueno" -- it's just
        // "Mastercard *2601" -- but AccountMapping keys off brand substrings
        // ("Ueno", "CLASICA", ...), so prefix it here or this card would
        // never match and every ueno purchase would be silently dropped as
        // "unrecognized_card".
        return Purchase(rawAmount.replace(".", ""), "Ueno ${cardText.trim()}", merchant)
    }
}

// Banco Continental (py.com.bancontinental.contiapp). Real notification
// bigText: "Banco Continental S.A.E.C.A.. informa. TRANS. APROBADA de la
// tarjeta DINELCO CLASICA 2744 , monto: 301.500-, en: CONTIMARKET
// CHECKOUT." The app also sends marketing/cashback notifications
// ("Ahorraste Gs. X en ...", promos) through the same channel -- those
// don't contain "TRANS. APROBADA" and are silently skipped.
object ContinentalExtractor : BankNotificationExtractor {
    private val PATTERN = Regex(
        """TRANS\.\s*APROBADA de la tarjeta\s+(.+?)\s*,\s*monto:\s*([\d.]+)-?\s*,\s*en:\s*(.+?)\.?\s*$"""
    )

    override fun extract(title: String, text: String): Purchase? {
        val match = PATTERN.find(text) ?: return null
        val (cardText, rawAmount, merchant) = match.destructured
        return Purchase(rawAmount.replace(".", ""), cardText.trim(), merchant.trim())
    }
}

object BankNotificationExtractors {
    private val BY_PACKAGE: Map<String, BankNotificationExtractor> = mapOf(
        "com.google.android.apps.walletnfcrel" to WalletTapExtractor,
        "py.com.elcomercio.retailbanking" to UenoBankExtractor,
        "py.com.bancontinental.contiapp" to ContinentalExtractor
    )

    fun forPackage(packageName: String): BankNotificationExtractor? = BY_PACKAGE[packageName]

    val watchedPackages: Set<String> get() = BY_PACKAGE.keys
}
