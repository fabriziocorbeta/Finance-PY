package py.com.cdco.financespy.wallet

data class Purchase(val amount: String, val cardText: String, val merchant: String)

interface BankNotificationExtractor {
    // Returns every purchase found in one notification, not just the first.
    // See ContinentalSmsExtractor: grouped/delayed SMS notifications can
    // carry more than one transaction in a single post.
    fun extract(title: String, text: String): List<Purchase>
}

// Google Wallet NFC tap-to-pay. Notification title IS the merchant name
// here (Wallet doesn't echo it in the body), text is "PYG<amount> con
// <card>". Amount comes comma-grouped ("150,000") -- WebhookClient already
// strips commas before posting, so left as-is.
object WalletTapExtractor : BankNotificationExtractor {
    private val PATTERN = Regex("""PYG([\d,]+) con (.+)""")

    override fun extract(title: String, text: String): List<Purchase> {
        val match = PATTERN.find(text) ?: return emptyList()
        val (amount, cardText) = match.destructured
        return listOf(Purchase(amount, cardText.trim(), merchant = title))
    }
}

// ueno bank (py.com.elcomercio.retailbanking). Real notification pair:
//   title: "Pagaste en GOOGLE *YouTube        LONDON        GBR"
//   text:  "Usaste tu tarjeta Mastercard *2601 para pagar Gs. 62.527 el dia 08-10-2026 22:34:15"
// Only "Pagaste en ..." notifications are purchases; reintegro/cashback ones
// ("¡Te reintegramos Gs. X!") don't match TITLE_PATTERN and are correctly
// skipped -- they're not an expense, counting them would double them up
// against the purchase that earned the cashback.
object UenoBankExtractor : BankNotificationExtractor {
    private val TITLE_PATTERN = Regex("""^Pagaste en\s+(.+)$""")
    private val TEXT_PATTERN = Regex("""Usaste tu tarjeta (.+?) para pagar Gs\.\s*([\d.]+)""")

    override fun extract(title: String, text: String): List<Purchase> {
        val merchantMatch = TITLE_PATTERN.find(title.trim()) ?: return emptyList()
        val textMatch = TEXT_PATTERN.find(text) ?: return emptyList()
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
        return listOf(Purchase(rawAmount.replace(".", ""), "Ueno ${cardText.trim()}", merchant))
    }
}

// Banco Continental does NOT push these through its own app
// (py.com.bancontinental.contiapp) -- that app only sends marketing/cashback
// notifications. Real transaction alerts arrive as plain SMS, delivered
// through the phone's default messaging app (confirmed live: sender
// shortcode "26684", via com.google.android.apps.messaging). Real text:
//   "Banco Continental S.A.E.C.A.. informa. TRANS. APROBADA de la tarjeta
//    DINELCO CLASICA 2744 , monto: 301.500-, en: CONTIMARKET CHECKOUT."
// The SMS app's notification is shared by every sender, and when several
// transaction SMS arrive while notifications are grouped (phone locked,
// Do Not Disturb, multiple purchases in quick succession), Android bundles
// them into ONE notification whose body is multiple "TRANS. APROBADA..."
// messages concatenated -- confirmed live (two real fuel purchases arrived
// bundled in a single notification). findAll (not find) extracts every one
// of them instead of just the first; a '.' only followed by whitespace-or-
// end (not just end-of-string) closes the merchant capture so it doesn't
// run on into the next bundled message.
object ContinentalSmsExtractor : BankNotificationExtractor {
    private val PATTERN = Regex(
        """TRANS\.\s*APROBADA de la tarjeta\s+(.+?)\s*,\s*monto:\s*([\d.]+)-?\s*,\s*en:\s*(.+?)\.(?=\s|$)"""
    )

    override fun extract(title: String, text: String): List<Purchase> {
        return PATTERN.findAll(text).map { match ->
            val (cardText, rawAmount, merchant) = match.destructured
            Purchase(rawAmount.replace(".", ""), cardText.trim(), merchant.trim())
        }.toList()
    }
}

object BankNotificationExtractors {
    private val BY_PACKAGE: Map<String, BankNotificationExtractor> = mapOf(
        "com.google.android.apps.walletnfcrel" to WalletTapExtractor,
        "py.com.elcomercio.retailbanking" to UenoBankExtractor,
        "com.google.android.apps.messaging" to ContinentalSmsExtractor
    )

    fun forPackage(packageName: String): BankNotificationExtractor? = BY_PACKAGE[packageName]

    val watchedPackages: Set<String> get() = BY_PACKAGE.keys
}
