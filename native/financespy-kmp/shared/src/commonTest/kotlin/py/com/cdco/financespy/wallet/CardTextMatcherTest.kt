package py.com.cdco.financespy.wallet

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

// Los textos de tarjeta de estos tests son los reales, extraídos de las entries
// ya capturadas en producción -- no inventados. Una versión anterior de este
// análisis usó nombres plausibles ("Mastercard Ueno ••2601") y dio un
// diagnóstico equivocado, porque el banco en realidad manda "UENO GPAY ••2601".
class CardTextMatcherTest {

    private val amex = CardTextMatcher.Candidate(
        id = "amex", name = "Amex Gold", cardIdentifier = "2269",
        institutionName = "American Express", accountType = "credit_card"
    )
    private val mastercardConti = CardTextMatcher.Candidate(
        id = "mc-conti", name = "Mastercard - Conti", cardIdentifier = "8394",
        institutionName = "Banco Continental", accountType = "credit_card"
    )
    private val dinelcoConti = CardTextMatcher.Candidate(
        id = "dinelco-conti", name = "DINELCO - CONTI", cardIdentifier = "2744",
        institutionName = "Banco Continental", accountType = "credit_card"
    )
    private val ueno = CardTextMatcher.Candidate(
        id = "ueno", name = "Mastercard - Ueno", cardIdentifier = "2601",
        institutionName = "Ueno Bank", accountType = "credit_card"
    )

    private val all = listOf(amex, mastercardConti, dinelcoConti, ueno)

    @Test
    fun `matches by card number across the real captured card texts`() {
        val cases = mapOf(
            "Amex Gold ••2269" to "amex",
            "MASTERCARD CLASICA ••8394" to "mc-conti",
            "DINELCO CLASICA 2744" to "dinelco-conti",
            "UENO GPAY ••2601" to "ueno"
        )

        cases.forEach { (cardText, expectedId) ->
            val result = CardTextMatcher.match(cardText, all)
            assertEquals(
                CardTextMatcher.Result.Matched(expectedId, CardTextMatcher.Strategy.CARD_NUMBER),
                result,
                "texto: $cardText"
            )
        }
    }

    // El bug exacto que motivó este matcher: ambas son tarjetas del Banco
    // Continental, así que el nombre del emisor no las distingue. Antes, el
    // substring por nombre mandaba esta compra a "Mastercard - Conti".
    @Test
    fun `dinelco and mastercard of the same bank are told apart by number`() {
        val result = CardTextMatcher.match("DINELCO CLASICA 2744", listOf(mastercardConti, dinelcoConti))

        assertEquals(
            CardTextMatcher.Result.Matched("dinelco-conti", CardTextMatcher.Strategy.CARD_NUMBER),
            result
        )
    }

    @Test
    fun `falls back to institution when no account has a card number`() {
        val sinNumero = listOf(
            ueno.copy(cardIdentifier = null),
            amex.copy(cardIdentifier = null)
        )

        val result = CardTextMatcher.match("Compra con Ueno Bank", sinNumero)

        assertEquals(
            CardTextMatcher.Result.Matched("ueno", CardTextMatcher.Strategy.INSTITUTION),
            result
        )
    }

    // Sin número, dos tarjetas del mismo banco son indistinguibles. Preferimos
    // decir "no sé" y que la captura se encole, antes que elegir una al azar.
    @Test
    fun `two cards of the same bank without numbers are ambiguous, not guessed`() {
        val sinNumero = listOf(
            mastercardConti.copy(cardIdentifier = null),
            dinelcoConti.copy(cardIdentifier = null)
        )

        val result = CardTextMatcher.match("Compra Banco Continental", sinNumero)

        assertTrue(result is CardTextMatcher.Result.Ambiguous, "esperaba Ambiguous, fue $result")
        assertEquals(setOf("mc-conti", "dinelco-conti"), result.accountIds.toSet())
    }

    @Test
    fun `card number wins over a conflicting institution match`() {
        // El texto nombra al Continental pero el número es el del Amex: manda
        // el número, que es el identificador fuerte.
        val result = CardTextMatcher.match("Banco Continental ••2269", all)

        assertEquals(
            CardTextMatcher.Result.Matched("amex", CardTextMatcher.Strategy.CARD_NUMBER),
            result
        )
    }

    @Test
    fun `an amount in the text is never mistaken for a card number`() {
        // 150000 es el monto, no una tarjeta. Al comparar por igualdad exacta
        // contra el identificador guardado, no matchea nada por número.
        val result = CardTextMatcher.match("PYG150000 con tarjeta", listOf(amex))

        assertEquals(CardTextMatcher.Result.None, result)
    }

    @Test
    fun `tolerates separators and spacing around the digits`() {
        listOf("Amex Gold ••2269", "Amex Gold ** 2269", "Amex Gold 2269", "AMEX GOLD ....2269").forEach {
            assertEquals(
                CardTextMatcher.Result.Matched("amex", CardTextMatcher.Strategy.CARD_NUMBER),
                CardTextMatcher.match(it, listOf(amex)),
                "texto: $it"
            )
        }
    }

    @Test
    fun `returns None for blank text or no accounts`() {
        assertEquals(CardTextMatcher.Result.None, CardTextMatcher.match("", all))
        assertEquals(CardTextMatcher.Result.None, CardTextMatcher.match("Amex Gold ••2269", emptyList()))
    }

    // Antes bastaba con que el nombre de la cuenta apareciera en el texto. Una
    // cuenta llamada "Oro" matcheaba cualquier texto que dijera "oro"; ahora el
    // nombre por sí solo no es criterio de matcheo.
    @Test
    fun `a short account name no longer matches by itself`() {
        val oro = CardTextMatcher.Candidate(
            id = "oro", name = "Oro", cardIdentifier = null,
            institutionName = null, accountType = "investment"
        )

        assertEquals(CardTextMatcher.Result.None, CardTextMatcher.match("COMPRA ORO MOLIDO SA", listOf(oro)))
    }
}
