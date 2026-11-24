package py.com.cdco.financespy.utils

/**
 * Locale-aware monetary input parser supporting both Paraguayan/LatAm formatting
 * (`.` thousands, `,` decimals — e.g. `150.000`, `1.250.000`, `12,50`) and US
 * formatting (`,` thousands, `.` decimals — e.g. `1,250.50`, `12.50`).
 *
 * Prevents the silent 1000x corruption caused by calling `String.toDoubleOrNull()`
 * on Paraguayan Guaraní inputs like `"150.000"`.
 */
object AmountParser {
    private val ZERO_MINOR_UNIT_CURRENCIES = setOf("PYG", "GUARANI", "GUARANIES")

    fun parse(raw: String, currency: String? = null): Double? = parseToDouble(raw, currency)

    fun parseToDouble(raw: String, currency: String? = null): Double? {
        return toCanonicalDecimalString(raw, currency)?.toDoubleOrNull()
    }

    fun toCanonicalDecimalString(raw: String, currency: String? = null): String? {
        val cleaned = raw
            .trim()
            .replace("₲", "")
            .replace("Gs.", "", ignoreCase = true)
            .replace("Gs", "", ignoreCase = true)
            .replace("$", "")
            .replace(" ", "")
        if (cleaned.isEmpty()) return null

        val isNegative = cleaned.startsWith("-")
        val unsigned = cleaned.removePrefix("-").removePrefix("+")
        if (unsigned.isEmpty() || !unsigned.all { it.isDigit() || it == '.' || it == ',' }) {
            return null
        }

        val isZeroMinorUnit = currency?.uppercase() in ZERO_MINOR_UNIT_CURRENCIES

        val normalized = when {
            isZeroMinorUnit -> {
                // Guaraníes have 0 minor units: `.` and `,` are thousands separators unless
                // explicitly followed by 1–2 trailing zeros like "150000,00".
                val lastComma = unsigned.lastIndexOf(',')
                val lastDot = unsigned.lastIndexOf('.')
                val sepIdx = maxOf(lastComma, lastDot)
                if (sepIdx >= 0) {
                    val trailing = unsigned.substring(sepIdx + 1)
                    val integerPart = unsigned.substring(0, sepIdx).replace(".", "").replace(",", "")
                    if (trailing.length in 1..2 && trailing.all { it == '0' } && integerPart.isNotEmpty()) {
                        integerPart
                    } else if (trailing.length == 3) {
                        unsigned.replace(".", "").replace(",", "")
                    } else {
                        // Reject non-zero fractional decimals on PYG or strip grouping if valid
                        val stripped = unsigned.replace(".", "").replace(",", "")
                        if (stripped.isEmpty()) return null
                        stripped
                    }
                } else {
                    unsigned
                }
            }
            unsigned.contains('.') && unsigned.contains(',') -> {
                // Whichever separator appears last is the decimal separator.
                if (unsigned.lastIndexOf(',') > unsigned.lastIndexOf('.')) {
                    unsigned.replace(".", "").replace(',', '.')
                } else {
                    unsigned.replace(",", "")
                }
            }
            unsigned.contains(',') -> {
                val parts = unsigned.split(',')
                if (parts.size > 2) {
                    // Multiple commas -> thousands separators (e.g. "1,250,000")
                    parts.joinToString("")
                } else if (parts[1].length == 3 && parts[0] != "0") {
                    // "1,000" -> thousands
                    parts.joinToString("")
                } else {
                    // "12,50" -> decimal
                    "${parts[0]}.${parts[1]}"
                }
            }
            unsigned.contains('.') -> {
                val parts = unsigned.split('.')
                if (parts.size > 2) {
                    // Multiple dots -> thousands separators (e.g. "1.250.000")
                    parts.joinToString("")
                } else if (parts[1].length == 3 && parts[0] != "0") {
                    // "150.000" -> thousands separator (LatAm/PY)
                    parts.joinToString("")
                } else {
                    // "12.50" or "0.500" -> decimal
                    unsigned
                }
            }
            else -> unsigned
        }

        if (normalized.toDoubleOrNull() == null) return null
        return if (isNegative) "-$normalized" else normalized
    }
}
