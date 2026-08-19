package py.com.cdco.financespy.db

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [AccountEntity::class, EntryEntity::class, TransactionEntity::class],
    version = 1,
    exportSchema = true
)
abstract class FinancePyDatabase : RoomDatabase() {
    abstract fun accountDao(): AccountDao
    abstract fun entryDao(): EntryDao
    abstract fun transactionDao(): TransactionDao
}

expect fun buildDatabase(): FinancePyDatabase
