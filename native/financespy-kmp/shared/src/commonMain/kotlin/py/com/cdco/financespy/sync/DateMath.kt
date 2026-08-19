package py.com.cdco.financespy.sync

fun subtractDays(isoDate: String, days: Int): String {
    val parts = isoDate.substring(0, 10).split("-").map { it.toInt() }
    var year = parts[0]
    var month = parts[1]
    var day = parts[2]
    repeat(days) {
        day--
        if (day < 1) {
            month--
            if (month < 1) { month = 12; year-- }
            day = daysInMonth(year, month)
        }
    }
    return "%04d-%02d-%02d".format(year, month, day)
}

private fun daysInMonth(year: Int, month: Int): Int = when (month) {
    1, 3, 5, 7, 8, 10, 12 -> 31
    4, 6, 9, 11 -> 30
    2 -> if (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) 29 else 28
    else -> 30
}
