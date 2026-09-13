package py.com.cdco.financespy.utils

fun formatPercent(value: Double?, decimals: Int = 1): String {
    if (value == null) return "0"
    val factor = when (decimals) {
        0 -> 1.0
        1 -> 10.0
        2 -> 100.0
        else -> 10.0
    }
    val rounded = (value * factor).toLong().toDouble() / factor
    val roundedLong = rounded.toLong()
    return if (decimals == 0 || rounded == roundedLong.toDouble()) {
        roundedLong.toString()
    } else {
        rounded.toString().replace('.', ',')
    }
}
