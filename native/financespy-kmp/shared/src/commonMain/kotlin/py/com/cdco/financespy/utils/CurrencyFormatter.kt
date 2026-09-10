package py.com.cdco.financespy.utils

fun formatMoney(amountCents: Long, currency: String?): String {
    val symbol = when (currency?.uppercase()) {
        "PYG", "GUARANI", "GUARANIES" -> "₲"
        "USD" -> "$"
        "EUR" -> "€"
        "BRL" -> "R$"
        "ARS" -> "$"
        null -> "$"
        else -> currency
    }

    val isNegative = amountCents < 0
    val absCents = if (isNegative) -amountCents else amountCents

    val isZeroMinorUnit = currency?.uppercase() in listOf("PYG", "GUARANI", "GUARANIES")

    val formattedNumber = if (isZeroMinorUnit) {
        formatWithThousandsSeparator(absCents)
    } else {
        val units = absCents / 100
        val cents = absCents % 100
        val centsStr = if (cents < 10) "0$cents" else "$cents"
        "${formatWithThousandsSeparator(units)},$centsStr"
    }

    val sign = if (isNegative) "-" else ""
    return "$sign$symbol $formattedNumber"
}

fun formatMoney(amount: Double, currency: String?): String {
    val isZeroMinorUnit = currency?.uppercase() in listOf("PYG", "GUARANI", "GUARANIES")
    val cents = if (isZeroMinorUnit) {
        amount.toLong()
    } else {
        (amount * 100.0).toLong()
    }
    return formatMoney(cents, currency)
}
private fun formatWithThousandsSeparator(number: Long): String {
    val str = number.toString()
    val sb = StringBuilder()
    var count = 0
    for (i in str.length - 1 downTo 0) {
        sb.append(str[i])
        count++
        if (count % 3 == 0 && i > 0) {
            sb.append(".")
        }
    }
    return sb.reverse().toString()
}
