package py.com.cdco.financespy.wallet

object AccountMapping {
    private val CARD_TO_ACCOUNT_ID = mapOf(
        "Ueno" to "74fa6687-bbf7-45d2-aa71-f06bca3b2013",
        "Amex" to "d47f5223-a988-46f5-9bc5-beefc4c7fefd",
        "CLASICA" to "952d06b3-f915-4cf1-b4c2-952fb131f2be",
        "GNB" to "43d84b14-b3be-44a9-be37-7ec1ae4661f2"
    )

    fun accountIdFor(cardText: String): String? {
        return CARD_TO_ACCOUNT_ID.entries
            .firstOrNull { (substring, _) -> cardText.contains(substring, ignoreCase = true) }
            ?.value
    }
}
