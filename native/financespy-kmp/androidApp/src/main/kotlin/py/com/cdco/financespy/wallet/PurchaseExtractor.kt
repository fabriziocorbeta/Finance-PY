package py.com.cdco.financespy.wallet

enum class TransactionNature { INCOME, EXPENSE }

data class Purchase(val amount: String, val cardText: String, val merchant: String, val nature: TransactionNature = TransactionNature.EXPENSE)

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
    private val PATTERN = Regex("""PYG\s*([\d,.]+) con (.+)""")

    override fun extract(title: String, text: String): List<Purchase> {
        val match = PATTERN.find(text) ?: return emptyList()
        val (amount, cardText) = match.destructured
        return listOf(Purchase(amount.replace(",", "").replace(".", ""), cardText.trim(), merchant = title))
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


// Banco GNB sends real transaction alerts as plain SMS, delivered
// through the phone's default messaging app. Real text for income:
//   "Banco GNB le informa que se registro un Credito en su Cuenta Nro.***  -001: Gs. 930.000 en concepto de Pagos 14/10/2026 19:05:55"
object GnbSmsExtractor : BankNotificationExtractor {
    private val CREDITO_PATTERN = Regex(
        """Credito en su (Cuenta Nro\..*?):\s*[Gg]s\.\s*([\d.]+)\s*en concepto de\s+(.+?)\s+\d{2}/\d{2}/\d{4}"""
    )

    override fun extract(title: String, text: String): List<Purchase> {
        return CREDITO_PATTERN.findAll(text).map { match ->
            val (accountFragment, rawAmount, merchant) = match.destructured
            // GNB's own SMS text never says "GNB" near the account identifier
            // (it's just "Cuenta Nro.*** -001") -- but AccountMapping keys off
            // brand substrings, same reasoning as UenoBankExtractor above, so
            // prefix it here or this would always be dropped as
            // "unrecognized_card".
            //
            // The prefix must be the FULL real account name ("Banco GNB"),
            // not a bare "GNB": this family has three GNB-ish accounts
            // ("Banco GNB", a stale unused "GNB", and "MasterCard - GNB"),
            // and AccountMapping.accountIdFor does a bidirectional substring
            // match against AccountDao.observeAll() (ORDER BY name ASC),
            // picking the first account whose name is contained in cardText
            // or vice versa. A bare "GNB" prefix matches the stale "GNB"
            // account (alphabetically after "Banco GNB") instead of the
            // real one -- confirmed against prod: "Banco GNB" has 31 real
            // entries through 2026-10, the bare "GNB" account has exactly
            // 1 entry from 2024. "Banco GNB " is still a substring-safe
            // prefix match for "Banco GNB" itself and sorts first
            // alphabetically, so it wins over both other candidates.
            Purchase(
                amount = rawAmount.replace(".", ""),
                cardText = "Banco GNB ${accountFragment.trim()}",
                merchant = merchant.trim(),
                nature = TransactionNature.INCOME
            )
        }.toList()
    }
}

object ItauSmsExtractor : BankNotificationExtractor {
    private val PATTERN = Regex(
        """Registramos un debito en tu Cuenta\s+\*+(\d+)\s+de\s+Gs\.\*+([\d.]+)\s+por\s+(.+?)\s+al\s+\d{2}/\d{2}/\d{4}"""
    )

    override fun extract(title: String, text: String): List<Purchase> {
        return PATTERN.findAll(text).map { match ->
            val (_, rawAmount, merchant) = match.destructured
            // Use "Itau" as the cardText since we match "Banco ITAU" with substring.
            Purchase(rawAmount.replace(".", ""), "Itau", merchant.trim())
        }.toList()
    }
}

// Unlike real Continental transaction alerts (SMS, see ContinentalSmsExtractor's
// own comment on why), the Contiapp itself (py.com.bancontinental.contiapp) was
// confirmed in a prior session to push ONLY marketing/cashback notifications --
// no real transaction data -- which is why that package was never added to
// BY_PACKAGE. That was too broad a conclusion: the specific "reintegro"
// confirmation push ("Ahorraste Gs. 155.275 en CONTIMARKET CHECKOUT. Seguí
// sumando reintegros con tu tarjeta Continental.") DOES carry a real amount --
// it's Continental crediting cashback back to the user, a real income event,
// not an ad. Every other Contiapp push seen in the wild (maintenance notices,
// security tips, "pedí tu tarjeta internacional", card-pickup reminders) has
// no Gs. amount at all, so this pattern can't accidentally match them.
object ContinentalCashbackExtractor : BankNotificationExtractor {
    private val PATTERN = Regex(
        """Ahorraste\s+Gs\.\s*([\d.]+)\s+en\s+(.+?)\.\s*Segu[ií]"""
    )

    override fun extract(title: String, text: String): List<Purchase> {
        return PATTERN.findAll(text).map { match ->
            val (rawAmount, merchant) = match.destructured
            // "Banco Continental" is the only real account this can
            // unambiguously match (AccountMapping does a bidirectional
            // substring check against AccountDao.observeAll()) -- there's
            // no account-number fragment in this notification to append,
            // unlike GnbSmsExtractor, so the plain account name is enough.
            Purchase(
                amount = rawAmount.replace(".", ""),
                cardText = "Banco Continental",
                merchant = merchant.trim(),
                nature = TransactionNature.INCOME
            )
        }.toList()
    }
}

object BankNotificationExtractors {
    private val BY_PACKAGE: Map<String, List<BankNotificationExtractor>> = mapOf(
        "com.google.android.apps.walletnfcrel" to listOf(WalletTapExtractor),
        "py.com.elcomercio.retailbanking" to listOf(UenoBankExtractor),
        "com.google.android.apps.messaging" to listOf(ContinentalSmsExtractor, GnbSmsExtractor, ItauSmsExtractor),
        // Samsung Messages is the default SMS app on Samsung phones (Google
        // Messages isn't installed/used there) -- same SMS text, same
        // extractors, just a different package posting the notification.
        "com.samsung.android.messaging" to listOf(ContinentalSmsExtractor, GnbSmsExtractor, ItauSmsExtractor),
        "py.com.bancontinental.contiapp" to listOf(ContinentalCashbackExtractor)
    )

    fun forPackage(packageName: String): List<BankNotificationExtractor> = BY_PACKAGE[packageName] ?: emptyList()

    val watchedPackages: Set<String> get() = BY_PACKAGE.keys
}
