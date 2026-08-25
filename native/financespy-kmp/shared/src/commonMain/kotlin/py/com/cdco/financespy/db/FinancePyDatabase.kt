package py.com.cdco.financespy.db

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [
        AccountEntity::class, EntryEntity::class, TransactionEntity::class,
        RuleEntity::class, RuleRunEntity::class, ReceivableEntity::class
    ],
    version = 3,
    exportSchema = true
)
abstract class FinancePyDatabase : RoomDatabase() {
    abstract fun accountDao(): AccountDao
    abstract fun entryDao(): EntryDao
    abstract fun transactionDao(): TransactionDao
    abstract fun ruleDao(): RuleDao
    abstract fun ruleRunDao(): RuleRunDao
    abstract fun receivableDao(): ReceivableDao
}

expect fun buildDatabase(): FinancePyDatabase
