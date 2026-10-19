package py.com.cdco.financespy.wallet

// Resuelve a qué cuenta pertenece el texto de tarjeta que manda el banco en una
// notificación. Puro y sin dependencias de Android para poder testearlo directo.
//
// El orden importa y no es arbitrario. Mapear por nombre de cuenta --lo único
// que se hacía antes-- cargó una compra en la cuenta equivocada el 2026-10-10:
// "DINELCO CLASICA 2744" matcheó la cuenta "Mastercard - Conti" porque ambas
// contienen "Conti". Son dos tarjetas distintas del mismo banco, así que el
// nombre del emisor nunca alcanza para distinguirlas; los últimos 4 dígitos sí.
object CardTextMatcher {

    data class Candidate(
        val id: String,
        val name: String,
        val cardIdentifier: String?,
        val institutionName: String?,
        val accountType: String?
    )

    sealed interface Result {
        /** Una sola cuenta compatible. */
        data class Matched(val accountId: String, val by: Strategy) : Result
        /** Varias cuentas igual de compatibles: no se adivina. */
        data class Ambiguous(val accountIds: List<String>, val by: Strategy) : Result
        /** Ninguna cuenta compatible. */
        data object None : Result
    }

    enum class Strategy { CARD_NUMBER, INSTITUTION, CARD_TYPE }

    // Tipos de tarjeta que los bancos nombran en la notificación. Solo se usan
    // como último recurso, y nunca para elegir entre dos cuentas del mismo tipo.
    private val CARD_TYPES = listOf("mastercard", "visa", "amex", "american express", "dinelco", "cabal")

    fun match(cardText: String, accounts: List<Candidate>): Result {
        if (cardText.isBlank() || accounts.isEmpty()) return Result.None

        byCardNumber(cardText, accounts)?.let { return it }
        byInstitution(cardText, accounts)?.let { return it }
        byCardType(cardText, accounts)?.let { return it }

        return Result.None
    }

    /** Nivel 1 -- los últimos 4 dígitos. Es el único identificador estable. */
    private fun byCardNumber(cardText: String, accounts: List<Candidate>): Result? {
        val digitGroups = DIGIT_GROUP.findAll(cardText).map { it.value }.toList()
        if (digitGroups.isEmpty()) return null

        val hits = accounts.filter { account ->
            val id = account.cardIdentifier?.filter(Char::isDigit)
            !id.isNullOrBlank() && digitGroups.any { it == id }
        }
        return hits.toResult(Strategy.CARD_NUMBER)
    }

    /**
     * Nivel 2 -- el nombre del banco. Desempata solo si el emisor identifica una
     * única cuenta; con dos tarjetas del mismo banco esto devuelve Ambiguous a
     * propósito, que es exactamente el caso Mastercard/Dinelco del Continental.
     */
    private fun byInstitution(cardText: String, accounts: List<Candidate>): Result? {
        val haystack = cardText.lowercase()
        val hits = accounts.filter { account ->
            val institution = account.institutionName?.lowercase()?.trim()
            !institution.isNullOrBlank() && haystack.contains(institution)
        }
        return hits.toResult(Strategy.INSTITUTION)
    }

    /** Nivel 3 -- el tipo de tarjeta nombrado en el texto, contra el nombre de la cuenta. */
    private fun byCardType(cardText: String, accounts: List<Candidate>): Result? {
        val haystack = cardText.lowercase()
        val mentioned = CARD_TYPES.filter { haystack.contains(it) }
        if (mentioned.isEmpty()) return null

        val hits = accounts.filter { account ->
            val name = account.name.lowercase()
            mentioned.any { name.contains(it) }
        }
        return hits.toResult(Strategy.CARD_TYPE)
    }

    private fun List<Candidate>.toResult(by: Strategy): Result? = when (size) {
        0 -> null
        1 -> Result.Matched(first().id, by)
        else -> Result.Ambiguous(map { it.id }, by)
    }

    // 3 o más dígitos seguidos: cubre "••2269", "** 2269" y "2744" pelado, y
    // descarta los montos porque se compara por igualdad exacta contra el
    // identificador guardado, no por "contiene".
    private val DIGIT_GROUP = Regex("""\d{3,}""")
}
