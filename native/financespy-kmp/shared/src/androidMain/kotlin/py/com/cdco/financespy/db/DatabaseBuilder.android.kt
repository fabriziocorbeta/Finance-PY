package py.com.cdco.financespy.db

import android.content.Context
import androidx.room.Room
import androidx.sqlite.driver.bundled.BundledSQLiteDriver

private lateinit var appContext: Context

fun initDatabaseBuilder(context: Context) {
    appContext = context.applicationContext
}

actual fun buildDatabase(): FinancePyDatabase {
    val dbPath = appContext.getDatabasePath("financespy.db").absolutePath
    return Room.databaseBuilder(appContext, FinancePyDatabase::class.java, dbPath)
        .setDriver(BundledSQLiteDriver())
        .fallbackToDestructiveMigration(dropAllTables = true)
        .build()
}
