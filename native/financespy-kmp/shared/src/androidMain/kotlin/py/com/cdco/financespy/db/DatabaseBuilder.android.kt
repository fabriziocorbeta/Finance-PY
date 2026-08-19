package py.com.cdco.financespy.db

import android.content.Context
import androidx.room.Room
import androidx.sqlite.driver.bundled.BundledSQLiteDriver

private lateinit var appContext: Context

fun initDatabaseBuilder(context: Context) {
    appContext = context.applicationContext
}

actual fun buildDatabase(): FinancePyDatabase =
    Room.databaseBuilder(appContext, FinancePyDatabase::class.java, "financespy.db")
        .setDriver(BundledSQLiteDriver())
        .build()
