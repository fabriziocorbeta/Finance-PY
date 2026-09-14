package py.com.cdco.financespy.utils

import kotlin.math.abs
import kotlin.math.roundToLong

/**
 * Formats a Double percentage value to a string with a fixed number of decimals (default 1).
 * Example:
 * formatPercent(12.847293847) -> "12.8%"
 * formatPercent(12.0) -> "12.0%"
 * formatPercent(null) -> ""
 */
fun formatPercent(value: Double?, decimals: Int = 1): String {
    if (value == null) return ""
    return "${formatDecimal(value, decimals)}%"
}

fun formatDecimal(value: Double, decimals: Int = 1): String {
    if (decimals <= 0) {
        return value.roundToLong().toString()
    }
    var factor = 1.0
    repeat(decimals) { factor *= 10.0 }

    val roundedUnits = (abs(value) * factor).roundToLong()
    val integerPart = roundedUnits / factor.toLong()
    val fractionalPart = roundedUnits % factor.toLong()

    val sign = if (value < 0 && roundedUnits != 0L) "-" else ""
    val fracStr = fractionalPart.toString().padStart(decimals, '0')
    return "$sign$integerPart.$fracStr"
}
