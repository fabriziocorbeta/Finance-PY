package py.com.cdco.financespy.sync

import java.time.LocalDate

actual fun currentIsoDate(): String = LocalDate.now().toString()
