package py.com.cdco.financespy.db

import androidx.room.Room
import androidx.sqlite.driver.bundled.BundledSQLiteDriver
import androidx.test.core.app.ApplicationProvider
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals

@RunWith(RobolectricTestRunner::class)
class DatabaseSmokeTest {
    @Test
    fun upsertAndReadAccount() = runTest {
        val db = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            FinancePyDatabase::class.java
        ).setDriver(BundledSQLiteDriver()).build()

        val account = AccountEntity(
            id = "acc-1", name = "Cuenta Test", balanceCents = 100000L,
            cashBalanceCents = 100000L, currency = "PYG", classification = "asset",
            accountType = "depository", subtype = null, status = "active",
            updatedAt = "2026-08-19T00:00:00Z"
        )
        db.accountDao().upsertAll(listOf(account))

        var result: List<AccountEntity> = emptyList()
        db.accountDao().observeAll().collect { result = it; return@collect }
        assertEquals(1, result.size)
        assertEquals("Cuenta Test", result.first().name)
        db.close()
    }
}
