package py.com.cdco.financespy.utils

import kotlin.math.abs
import kotlin.math.roundToLong

object CurrencyFormatter {
    fun formatMoney(amountCents: Long, currency: String? = null): String {
        val amount = amountCents / 100.0
        return formatMoney(amount, currency)
    }

    fun formatMoney(amount: Double, currency: String? = null): String {
        val curr = currency?.trim()
        val isPyg = curr.equals("PYG", ignoreCase = true) || curr == "₲"

        val formattedNumber = if (isPyg) {
            formatIntegerWithSeparators(amount.roundToLong())
        } else {
            formatDecimalWithSeparators(amount)
        }

        return when {
            curr.isNullOrBlank() -> formattedNumber
            curr == "₲" || curr == "$" || curr == "€" -> "$curr $formattedNumber"
            else -> "$formattedNumber $curr"
        }
    }

    private fun formatIntegerWithSeparators(value: Long): String {
        val isNegative = value < 0
        val absStr = abs(value).toString()
        val sb = StringBuilder()
        var count = 0
        for (i in absStr.length - 1 downTo 0) {
            if (count > 0 && count % 3 == 0) {
                sb.append('.')
            }
            sb.append(absStr[i])
            count++
        }
        val result = sb.reverse().toString()
        return if (isNegative) "-$result" else result
    }

    private fun formatDecimalWithSeparators(value: Double): String {
        val isNegative = value < 0
        val absValue = abs(value)
        val cents = (absValue * 100).roundToLong()
        val wholePart = cents / 100
        val decimalPart = cents % 100

        val formattedWhole = formatIntegerWithSeparators(wholePart)
        val decimalStr = if (decimalPart < 10) "0$decimalPart" else "$decimalPart"

        return if (isNegative) "-$formattedWhole.$decimalStr" else "$formattedWhole.$decimalStr"
    }
}

fun formatMoney(amountCents: Long, currency: String? = null): String =
    CurrencyFormatter.formatMoney(amountCents, currency)

fun formatMoney(amount: Double, currency: String? = null): String =
    CurrencyFormatter.formatMoney(amount, currency)
