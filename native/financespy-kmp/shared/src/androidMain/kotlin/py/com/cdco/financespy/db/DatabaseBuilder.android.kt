package py.com.cdco.financespy.db

import android.content.Context
import androidx.room.Room
import androidx.sqlite.driver.bundled.BundledSQLiteDriver

private lateinit var appContext: Context

fun initDatabaseBuilder(context: Context) {
    appContext = context.applicationContext
}

@Volatile
private var instance: FinancePyDatabase? = null

private val instanceLock = Any()

// AccountMapping.accountIdFor calls buildDatabase() once per incoming bank
// notification; before this, that meant a brand new Room/SQLite connection
// (never closed) per notification -- a connection leak that grows unbounded
// the longer the wallet-capture listener runs. Double-checked locking so
// every caller (MainActivity's `by lazy` included) shares one connection.
actual fun buildDatabase(): FinancePyDatabase {
    return instance ?: synchronized(instanceLock) {
        instance ?: run {
            val dbPath = appContext.getDatabasePath("financespy.db").absolutePath
            Room.databaseBuilder(appContext, FinancePyDatabase::class.java, dbPath)
                .setDriver(BundledSQLiteDriver())
                .fallbackToDestructiveMigration(dropAllTables = true)
                .build()
                .also { instance = it }
        }
    }
}
