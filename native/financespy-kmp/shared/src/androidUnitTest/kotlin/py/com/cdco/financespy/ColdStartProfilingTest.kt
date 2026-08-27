package py.com.cdco.financespy

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.auth.AndroidTokenStorage
import py.com.cdco.financespy.auth.AuthRepository
import py.com.cdco.financespy.db.FinancePyDatabase
import py.com.cdco.financespy.db.initDatabaseBuilder
import py.com.cdco.financespy.network.ApiClient
import py.com.cdco.financespy.screens.DashboardViewModel
import py.com.cdco.financespy.screens.GoalsListViewModel
import py.com.cdco.financespy.screens.RulesListViewModel
import py.com.cdco.financespy.screens.TransactionsViewModel
import py.com.cdco.financespy.sync.SyncEngine
import py.com.cdco.financespy.sync.currentIsoDate
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlin.system.measureTimeMillis

@RunWith(RobolectricTestRunner::class)
class ColdStartProfilingTest {

    @Test
    fun profileUnoptimizedColdStartBaseline() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val runDurations = mutableListOf<Long>()

        repeat(5) { runIndex ->
            val duration = measureTimeMillis {
                initDatabaseBuilder(context)
                val tokenStorage = AndroidTokenStorage(context)
                val httpClient = ApiClient.create(tokenStorage)
                val authRepository = AuthRepository(httpClient, tokenStorage)
                val api = FinancePyApi(httpClient)
                val database = Room.inMemoryDatabaseBuilder(
                    context,
                    FinancePyDatabase::class.java
                ).build()
                val syncEngine = SyncEngine(
                    api = api,
                    accountDao = database.accountDao(),
                    entryDao = database.entryDao(),
                    transactionDao = database.transactionDao(),
                    ruleDao = database.ruleDao(),
                    ruleRunDao = database.ruleRunDao(),
                    goalDao = database.goalDao(),
                    currentDateProvider = { currentIsoDate() }
                )
                val scope = TestScope()
                DashboardViewModel(
                    scope = scope,
                    syncEngine = syncEngine,
                    api = api,
                    accountDao = database.accountDao(),
                    entryDao = database.entryDao()
                )
                TransactionsViewModel(
                    scope = scope,
                    entryDao = database.entryDao()
                )
                RulesListViewModel(
                    scope = scope,
                    ruleDao = database.ruleDao()
                )
                GoalsListViewModel(
                    scope = scope,
                    goalDao = database.goalDao()
                )
            }
            runDurations.add(duration)
            println("Baseline Run ${runIndex + 1}: ${duration} ms")
        }

        val averageBaseline = runDurations.average()
        println("=== COLD START BASELINE AVERAGE (5 runs): ${averageBaseline} ms ===")
    }

    @Test
    fun profileOptimizedColdStart() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val runDurations = mutableListOf<Long>()

        repeat(5) { runIndex ->
            val duration = measureTimeMillis {
                initDatabaseBuilder(context)

                val tokenStorage by lazy { AndroidTokenStorage(context) }
                val httpClient by lazy { ApiClient.create(tokenStorage) }
                val authRepository by lazy { AuthRepository(httpClient, tokenStorage) }
                val api by lazy { FinancePyApi(httpClient) }
                val database by lazy {
                    Room.inMemoryDatabaseBuilder(
                        context,
                        FinancePyDatabase::class.java
                    ).build()
                }
                val syncEngine by lazy {
                    SyncEngine(
                        api = api,
                        accountDao = database.accountDao(),
                        entryDao = database.entryDao(),
                        transactionDao = database.transactionDao(),
                        ruleDao = database.ruleDao(),
                        ruleRunDao = database.ruleRunDao(),
                        goalDao = database.goalDao(),
                        currentDateProvider = { currentIsoDate() }
                    )
                }
                val scope = TestScope()
                val dashboardViewModel by lazy {
                    DashboardViewModel(
                        scope = scope,
                        syncEngine = syncEngine,
                        api = api,
                        accountDao = database.accountDao(),
                        entryDao = database.entryDao()
                    )
                }
                val transactionsViewModel by lazy {
                    TransactionsViewModel(
                        scope = scope,
                        entryDao = database.entryDao()
                    )
                }
                val rulesListViewModel by lazy {
                    RulesListViewModel(
                        scope = scope,
                        ruleDao = database.ruleDao()
                    )
                }
                val goalsListViewModel by lazy {
                    GoalsListViewModel(
                        scope = scope,
                        goalDao = database.goalDao()
                    )
                }
            }
            runDurations.add(duration)
            println("Optimized Run ${runIndex + 1}: ${duration} ms")
        }

        val averageOptimized = runDurations.average()
        println("=== OPTIMIZED COLD START AVERAGE (5 runs): ${averageOptimized} ms ===")
    }
}
