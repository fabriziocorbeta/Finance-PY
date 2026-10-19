package py.com.cdco.financespy.theme

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Looper
import android.view.View
import androidx.activity.ComponentActivity
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.ComposeView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import io.ktor.client.HttpClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import py.com.cdco.financespy.FakeDashboardCache
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.AccountGroupDto
import py.com.cdco.financespy.api.dto.AccountItemDto
import py.com.cdco.financespy.api.dto.AccountRefDto
import py.com.cdco.financespy.api.dto.CashflowSankeyDto
import py.com.cdco.financespy.api.dto.CategoryRefDto
import py.com.cdco.financespy.api.dto.ClassificationGroupDto
import py.com.cdco.financespy.api.dto.DashboardBalanceSheetDto
import py.com.cdco.financespy.api.dto.DashboardDto
import py.com.cdco.financespy.api.dto.DonutCategoryDto
import py.com.cdco.financespy.api.dto.FamilySettingsDto
import py.com.cdco.financespy.api.dto.GoalDto
import py.com.cdco.financespy.api.dto.InvestmentSummaryDto
import py.com.cdco.financespy.api.dto.MerchantRefDto
import py.com.cdco.financespy.api.dto.NetWorthDto
import py.com.cdco.financespy.api.dto.NetWorthSeriesPointDto
import py.com.cdco.financespy.api.dto.OutflowsDonutDto
import py.com.cdco.financespy.api.dto.PaginationDto
import py.com.cdco.financespy.api.dto.PeriodDto
import py.com.cdco.financespy.api.dto.ReceivableDto
import py.com.cdco.financespy.api.dto.RuleDto
import py.com.cdco.financespy.api.dto.SankeyLinkDto
import py.com.cdco.financespy.api.dto.SankeyNodeDto
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.api.dto.TransactionsResponse
import py.com.cdco.financespy.api.dto.TrendDto
import py.com.cdco.financespy.api.dto.UserDto
import py.com.cdco.financespy.auth.AuthRepository
import py.com.cdco.financespy.auth.TokenStorage
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity
import py.com.cdco.financespy.db.GoalDao
import py.com.cdco.financespy.db.GoalEntity
import py.com.cdco.financespy.db.ReceivableDao
import py.com.cdco.financespy.db.ReceivableEntity
import py.com.cdco.financespy.db.RuleDao
import py.com.cdco.financespy.db.RuleEntity
import py.com.cdco.financespy.db.RuleRunDao
import py.com.cdco.financespy.db.RuleRunEntity
import py.com.cdco.financespy.db.TransactionDao
import py.com.cdco.financespy.db.TransactionEntity
import py.com.cdco.financespy.navigation.NavItems
import py.com.cdco.financespy.navigation.Routes
import py.com.cdco.financespy.screens.DashboardScreen
import py.com.cdco.financespy.screens.DashboardViewModel
import py.com.cdco.financespy.screens.SettingsScreen
import py.com.cdco.financespy.screens.SettingsViewModel
import py.com.cdco.financespy.screens.TransactionsScreen
import py.com.cdco.financespy.screens.TransactionsViewModel
import py.com.cdco.financespy.sync.SyncEngine
import py.com.cdco.financespy.theme.components.AppBottomNav
import py.com.cdco.financespy.theme.components.AppCard
import java.io.File
import java.io.FileOutputStream
import kotlin.test.assertTrue

@RunWith(RobolectricTestRunner::class)
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@Config(sdk = [34], qualifiers = "w411dp-h891dp-xxhdpi")
class UiVariantVisualCaptureTest {

    private class DemoFinancePyApi : FinancePyApi(HttpClient()) {
        override suspend fun fetchAllAccounts(): List<AccountDto> = listOf(
            AccountDto(
                id = "acc-ita",
                name = "Itaú Cuenta Corriente",
                balance_cents = 48_500_000_00L,
                cash_balance_cents = 48_500_000_00L,
                currency = "PYG",
                classification = "asset",
                account_type = "Depository",
                subtype = "checking",
                status = "active",
                updated_at = "2026-10-18"
            ),
            AccountDto(
                id = "acc-cont",
                name = "Continental Ahorro",
                balance_cents = 92_300_000_00L,
                cash_balance_cents = 92_300_000_00L,
                currency = "PYG",
                classification = "asset",
                account_type = "Depository",
                subtype = "savings",
                status = "active",
                updated_at = "2026-10-18"
            ),
            AccountDto(
                id = "acc-tc",
                name = "Visa Infinite Itaú",
                balance_cents = 8_450_000_00L,
                cash_balance_cents = 8_450_000_00L,
                currency = "PYG",
                classification = "liability",
                account_type = "CreditCard",
                subtype = "credit_card",
                status = "active",
                updated_at = "2026-10-18"
            )
        )

        override suspend fun fetchRecentTransactions(startDate: String): List<TransactionListItemDto> =
            sampleTransactions()

        override suspend fun fetchTransactionsPage(
            page: Int,
            perPage: Int,
            startDate: String?,
            endDate: String?,
            categoryId: String?,
            search: String?,
            accountId: String?,
            type: String?
        ): TransactionsResponse = TransactionsResponse(
            transactions = sampleTransactions(),
            pagination = PaginationDto(page = 1, per_page = 25, total_count = 5, total_pages = 1)
        )

        override suspend fun fetchAllRules(): List<RuleDto> = emptyList()
        override suspend fun fetchAllGoals(): List<GoalDto> = emptyList()
        override suspend fun fetchAllReceivables(): List<ReceivableDto> = emptyList()

        override suspend fun fetchDashboard(period: String?): DashboardDto = DashboardDto(
            greeting_name = "Fabrizio",
            currency = "PYG",
            period = PeriodDto(key = period ?: "current_month", label = "Este mes"),
            net_worth = NetWorthDto(
                amount = 184_350_000.0,
                amount_cents = 184_350_000_00L,
                currency = "PYG",
                series = listOf(
                    NetWorthSeriesPointDto("2026-10-01", "1 Oct", 171_000_000.0),
                    NetWorthSeriesPointDto("2026-10-07", "7 Oct", 175_400_000.0),
                    NetWorthSeriesPointDto("2026-10-12", "12 Oct", 179_800_000.0),
                    NetWorthSeriesPointDto("2026-10-18", "18 Oct", 184_350_000.0)
                ),
                trend = TrendDto(
                    value = 13_350_000.0,
                    percent = 7.8,
                    percent_formatted = "+7,8%",
                    direction = "up",
                    color = "#10B981"
                )
            ),
            balance_sheet = DashboardBalanceSheetDto(
                classification_groups = listOf(
                    ClassificationGroupDto(
                        classification = "asset",
                        name = "Activos",
                        total = 192_800_000.0,
                        account_groups = listOf(
                            AccountGroupDto(
                                key = "depository",
                                name = "Efectivo y Bancos",
                                color = "#10B981",
                                weight = 73.0,
                                total = 140_800_000.0,
                                accounts = listOf(
                                    AccountItemDto("acc-cont", "Continental Ahorro", 92_300_000.0, currency = "PYG"),
                                    AccountItemDto("acc-ita", "Itaú Cuenta Corriente", 48_500_000.0, currency = "PYG")
                                )
                            ),
                            AccountGroupDto(
                                key = "investment",
                                name = "Inversiones CDA / Fondos",
                                color = "#3B82F6",
                                weight = 27.0,
                                total = 52_000_000.0,
                                accounts = listOf(
                                    AccountItemDto("acc-basa", "Basa Capital Fondo Mutuo", 52_000_000.0, currency = "PYG")
                                )
                            )
                        )
                    ),
                    ClassificationGroupDto(
                        classification = "liability",
                        name = "Pasivos",
                        total = 8_450_000.0,
                        account_groups = listOf(
                            AccountGroupDto(
                                key = "credit_card",
                                name = "Tarjetas de Crédito",
                                color = "#EF4444",
                                weight = 100.0,
                                total = 8_450_000.0,
                                accounts = listOf(
                                    AccountItemDto("acc-tc", "Visa Infinite Itaú", 8_450_000.0, currency = "PYG")
                                )
                            )
                        )
                    )
                )
            ),
            cashflow_sankey = CashflowSankeyDto(
                currency_symbol = "Gs.",
                nodes = listOf(
                    SankeyNodeDto("Ingresos", 24_500_000.0, 100.0, "#10B981"),
                    SankeyNodeDto("Supermercado", 4_200_000.0, 17.1, "#F59E0B"),
                    SankeyNodeDto("Ahorro", 20_300_000.0, 82.9, "#3B82F6")
                ),
                links = listOf(
                    SankeyLinkDto(0, 1, 4_200_000.0, "#F59E0B", 17.1),
                    SankeyLinkDto(0, 2, 20_300_000.0, "#3B82F6", 82.9)
                )
            ),
            outflows_donut = OutflowsDonutDto(
                currency = "PYG",
                currency_symbol = "Gs.",
                total = 6_850_000.0,
                categories = listOf(
                    DonutCategoryDto("cat-1", "Supermercado", 3_150_000.0, "PYG", 46.0, "#10B981"),
                    DonutCategoryDto("cat-2", "Restaurantes", 1_850_000.0, "PYG", 27.0, "#F59E0B"),
                    DonutCategoryDto("cat-3", "Combustible", 1_200_000.0, "PYG", 17.5, "#3B82F6"),
                    DonutCategoryDto("cat-4", "Servicios", 650_000.0, "PYG", 9.5, "#8B5CF6")
                )
            ),
            investment_summary = InvestmentSummaryDto(portfolio_value = 52_000_000.0, currency = "PYG")
        )

        override suspend fun fetchFamilySettings(): FamilySettingsDto = FamilySettingsDto(
            id = "fam-1",
            currency = "PYG",
            locale = "es",
            date_format = "dd/MM/yyyy",
            month_start_day = 1,
            created_at = "2026-01-01",
            updated_at = "2026-10-18",
            name = "Familia Corbeta",
            business_mode_enabled = true,
            current_user = UserDto(
                id = "usr-1",
                email = "fabrizio@financespy.com",
                first_name = "Fabrizio",
                last_name = "Corbeta",
                role = "admin"
            ),
            users = emptyList()
        )

        private fun sampleTransactions(): List<TransactionListItemDto> = listOf(
            TransactionListItemDto(
                id = "tx-1",
                date = "2026-10-18",
                amount_cents = 485_000L,
                signed_amount_cents = -485_000L,
                currency = "PYG",
                name = "Superseis Mcal. López",
                classification = "expense",
                account = AccountRefDto("acc-tc", "Visa Infinite Itaú", "CreditCard"),
                category = CategoryRefDto("cat-1", "Supermercado", "#10B981", "shopping-cart"),
                merchant = MerchantRefDto("mer-1", "Superseis"),
                created_at = "2026-10-18T14:20:00Z",
                updated_at = "2026-10-18T14:20:00Z"
            ),
            TransactionListItemDto(
                id = "tx-2",
                date = "2026-10-18",
                amount_cents = 165_000L,
                signed_amount_cents = -165_000L,
                currency = "PYG",
                name = "Café Consulado",
                classification = "expense",
                account = AccountRefDto("acc-ita", "Itaú Cuenta Corriente", "Depository"),
                category = CategoryRefDto("cat-2", "Restaurantes", "#F59E0B", "utensils"),
                merchant = MerchantRefDto("mer-2", "Café Consulado"),
                created_at = "2026-10-18T10:15:00Z",
                updated_at = "2026-10-18T10:15:00Z",
                pending = true
            ),
            TransactionListItemDto(
                id = "tx-3",
                date = "2026-10-17",
                amount_cents = 15_500_000L,
                signed_amount_cents = 15_500_000L,
                currency = "PYG",
                name = "Cobro Consultoría Mensual",
                classification = "income",
                account = AccountRefDto("acc-cont", "Continental Ahorro", "Depository"),
                category = CategoryRefDto("cat-3", "Ingresos", "#10B981", "briefcase"),
                merchant = null,
                created_at = "2026-10-17T18:00:00Z",
                updated_at = "2026-10-17T18:00:00Z"
            ),
            TransactionListItemDto(
                id = "tx-4",
                date = "2026-10-17",
                amount_cents = 350_000L,
                signed_amount_cents = -350_000L,
                currency = "PYG",
                name = "Shell Aviadores del Chaco",
                classification = "expense",
                account = AccountRefDto("acc-tc", "Visa Infinite Itaú", "CreditCard"),
                category = CategoryRefDto("cat-4", "Combustible", "#3B82F6", "fuel"),
                merchant = MerchantRefDto("mer-4", "Shell"),
                created_at = "2026-10-17T09:30:00Z",
                updated_at = "2026-10-17T09:30:00Z"
            ),
            TransactionListItemDto(
                id = "tx-5",
                date = "2026-10-16",
                amount_cents = 290_000L,
                signed_amount_cents = -290_000L,
                currency = "PYG",
                name = "ANDE Factura Octubre",
                classification = "expense",
                account = AccountRefDto("acc-ita", "Itaú Cuenta Corriente", "Depository"),
                category = CategoryRefDto("cat-5", "Servicios", "#8B5CF6", "bolt"),
                merchant = MerchantRefDto("mer-5", "ANDE"),
                created_at = "2026-10-16T11:00:00Z",
                updated_at = "2026-10-16T11:00:00Z"
            )
        )
    }

    private val dummyAccountDao = object : AccountDao {
        override fun observeAll(): Flow<List<AccountEntity>> = flowOf(emptyList())
        override suspend fun upsertAll(accounts: List<AccountEntity>) {}
        override suspend fun deleteAllExcept(ids: List<String>) {}
    }

    private val dummyEntryDao = object : EntryDao {
        override fun observeRecent(limit: Int): Flow<List<EntryEntity>> = flowOf(emptyList())
        override fun observeAll(): Flow<List<EntryEntity>> = flowOf(emptyList())
        override fun observeByAccountId(accountId: String): Flow<List<EntryEntity>> = flowOf(emptyList())
        override suspend fun upsertAll(entries: List<EntryEntity>) {}
        override suspend fun deleteStaleWithinWindow(activeIds: List<String>, windowStartDate: String) {}
    }

    private val dummyRuleDao = object : RuleDao {
        override fun observeAll(): Flow<List<RuleEntity>> = flowOf(emptyList())
        override suspend fun findById(id: String): RuleEntity? = null
        override suspend fun upsertAll(rules: List<RuleEntity>) {}
        override suspend fun deleteById(id: String) {}
        override suspend fun deleteAllExcept(ids: List<String>) {}
    }

    private val dummyRuleRunDao = object : RuleRunDao {
        override fun observeByRuleId(ruleId: String): Flow<List<RuleRunEntity>> = flowOf(emptyList())
        override suspend fun upsertAll(runs: List<RuleRunEntity>) {}
    }

    private val dummyGoalDao = object : GoalDao {
        override fun observeAll(): Flow<List<GoalEntity>> = flowOf(emptyList())
        override suspend fun findById(id: String): GoalEntity? = null
        override suspend fun upsertAll(goals: List<GoalEntity>) {}
        override suspend fun deleteById(id: String) {}
        override suspend fun deleteAllExcept(ids: List<String>) {}
    }

    private val dummyReceivableDao = object : ReceivableDao {
        override fun observeAll(): Flow<List<ReceivableEntity>> = flowOf(emptyList())
        override fun observeById(id: String): Flow<ReceivableEntity?> = flowOf(null)
        override suspend fun getById(id: String): ReceivableEntity? = null
        override suspend fun upsert(receivable: ReceivableEntity) {}
        override suspend fun upsertAll(receivables: List<ReceivableEntity>) {}
        override suspend fun deleteById(id: String) {}
        override suspend fun deleteAllExcept(ids: List<String>) {}
    }

    private val dummyTransactionDao = object : TransactionDao {
        override suspend fun upsertAll(transactions: List<TransactionEntity>) {}
        override suspend fun getAll(): List<TransactionEntity> = emptyList()
        override suspend fun findById(id: String): TransactionEntity? = null
    }

    private val fakeTokenStorage = object : TokenStorage {
        override suspend fun save(accessToken: String, refreshToken: String) {}
        override suspend fun accessToken(): String? = "demo-token"
        override suspend fun refreshToken(): String? = "demo-refresh"
        override suspend fun clear() {}
    }

    @Test
    fun renderBothVariantsAndCaptureSideBySideScreenshots() {
        val api = DemoFinancePyApi()
        val mainScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
        val syncEngine = SyncEngine(
            api = api,
            accountDao = dummyAccountDao,
            entryDao = dummyEntryDao,
            transactionDao = dummyTransactionDao,
            ruleDao = dummyRuleDao,
            ruleRunDao = dummyRuleRunDao,
            goalDao = dummyGoalDao,
            receivableDao = dummyReceivableDao,
            currentDateProvider = { "2026-10-18" }
        )
        val dashboardVm = DashboardViewModel(
            scope = mainScope,
            syncEngine = syncEngine,
            api = api,
            accountDao = dummyAccountDao,
            entryDao = dummyEntryDao,
            dashboardCache = FakeDashboardCache()
        )
        val transactionsVm = TransactionsViewModel(
            scope = mainScope,
            api = api,
            entryDao = dummyEntryDao,
            transactionDao = dummyTransactionDao,
            accountDao = dummyAccountDao
        )
        val settingsVm = SettingsViewModel(
            scope = mainScope,
            api = api,
            authRepository = AuthRepository(HttpClient(), fakeTokenStorage)
        )

        shadowOf(Looper.getMainLooper()).idle()

        val barItems = listOf(
            NavItems.DASHBOARD,
            NavItems.TRANSACTIONS,
            NavItems.REPORTS,
            NavItems.BUDGETS
        )

        val dashboardM3 = renderScreenToBitmap(UiVariant.MATERIAL3) {
            Box(modifier = Modifier.fillMaxSize()) {
                DashboardScreen(viewModel = dashboardVm)
                AppBottomNav(
                    items = barItems,
                    currentRoute = Routes.DASHBOARD,
                    onNavigate = {},
                    onMoreClick = {},
                    modifier = Modifier.align(Alignment.BottomCenter)
                )
            }
        }

        val dashboardIos = renderScreenToBitmap(UiVariant.IOS) {
            Box(modifier = Modifier.fillMaxSize()) {
                DashboardScreen(viewModel = dashboardVm)
                AppBottomNav(
                    items = barItems,
                    currentRoute = Routes.DASHBOARD,
                    onNavigate = {},
                    onMoreClick = {},
                    modifier = Modifier.align(Alignment.BottomCenter)
                )
            }
        }

        val transactionsM3 = renderScreenToBitmap(UiVariant.MATERIAL3) {
            Box(modifier = Modifier.fillMaxSize()) {
                TransactionsScreen(
                    viewModel = transactionsVm,
                    onTransactionClick = {},
                    onCreateClick = {}
                )
                AppBottomNav(
                    items = barItems,
                    currentRoute = Routes.TRANSACTIONS,
                    onNavigate = {},
                    onMoreClick = {},
                    modifier = Modifier.align(Alignment.BottomCenter)
                )
            }
        }

        val transactionsIos = renderScreenToBitmap(UiVariant.IOS) {
            Box(modifier = Modifier.fillMaxSize()) {
                TransactionsScreen(
                    viewModel = transactionsVm,
                    onTransactionClick = {},
                    onCreateClick = {}
                )
                AppBottomNav(
                    items = barItems,
                    currentRoute = Routes.TRANSACTIONS,
                    onNavigate = {},
                    onMoreClick = {},
                    modifier = Modifier.align(Alignment.BottomCenter)
                )
            }
        }

        val settingsM3 = renderScreenToBitmap(UiVariant.MATERIAL3) {
            SettingsScreen(
                viewModel = settingsVm,
                uiVariant = UiVariant.MATERIAL3,
                onSelectUiVariant = {},
                onLoggedOut = {},
                onBack = {}
            )
        }

        val settingsIos = renderScreenToBitmap(UiVariant.IOS) {
            SettingsScreen(
                viewModel = settingsVm,
                uiVariant = UiVariant.IOS,
                onSelectUiVariant = {},
                onLoggedOut = {},
                onBack = {}
            )
        }

        // Captura con contenido pasando por debajo de la barra inferior (scrolling content),
        // donde la translucidez y refracción del glass se aprecian directamente.
        val contentUnderNavM3 = renderScreenToBitmap(UiVariant.MATERIAL3) {
            Box(modifier = Modifier.fillMaxSize().background(FinancePyColors.surface())) {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(20) { idx ->
                        AppCard(modifier = Modifier.fillMaxWidth()) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "Movimiento #$idx — Supermercado Stock",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textPrimary()
                                )
                                Text(
                                    text = "-₲ 245.000",
                                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                    color = FinancePyColors.destructive()
                                )
                            }
                        }
                    }
                }
                AppBottomNav(
                    items = barItems,
                    currentRoute = Routes.TRANSACTIONS,
                    onNavigate = {},
                    onMoreClick = {},
                    modifier = Modifier.align(Alignment.BottomCenter)
                )
            }
        }

        val contentUnderNavIos = renderScreenToBitmap(UiVariant.IOS) {
            Box(modifier = Modifier.fillMaxSize().background(FinancePyColors.surface())) {
                LazyColumn(
                    modifier = Modifier.fillMaxSize(),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(20) { idx ->
                        AppCard(modifier = Modifier.fillMaxWidth()) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "Movimiento #$idx — Supermercado Stock",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = FinancePyColors.textPrimary()
                                )
                                Text(
                                    text = "-₲ 245.000",
                                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                    color = FinancePyColors.destructive()
                                )
                            }
                        }
                    }
                }
                AppBottomNav(
                    items = barItems,
                    currentRoute = Routes.TRANSACTIONS,
                    onNavigate = {},
                    onMoreClick = {},
                    modifier = Modifier.align(Alignment.BottomCenter)
                )
            }
        }

        // Las dos variantes tienen que renderizar distinto. Antes esto solo
        // afirmaba `width > 0`, que no puede fallar: si LocalUiVariant quedara
        // mal cableado y ambas variantes cayeran a Material 3, o si una pantalla
        // saliera en blanco, el test seguía en verde y las capturas quedaban
        // idénticas sin que nadie se enterara.
        assertDiffer(dashboardM3, dashboardIos, "Dashboard")
        assertDiffer(transactionsM3, transactionsIos, "Transacciones")
        assertDiffer(settingsM3, settingsIos, "Ajustes")
        assertDiffer(contentUnderNavM3, contentUnderNavIos, "Barra inferior con contenido debajo")

        val outDir = File("build/outputs/screenshots/ui-variants")
        outDir.mkdirs()

        saveSideBySide(
            left = dashboardM3,
            right = dashboardIos,
            leftLabel = "Material 3 (Actual / Default)",
            rightLabel = "iOS 26 Liquid Glass",
            targetFile = File(outDir, "dashboard_side_by_side.png")
        )
        saveSideBySide(
            left = transactionsM3,
            right = transactionsIos,
            leftLabel = "Material 3 (Actual / Default)",
            rightLabel = "iOS 26 Liquid Glass",
            targetFile = File(outDir, "transactions_side_by_side.png")
        )
        saveSideBySide(
            left = settingsM3,
            right = settingsIos,
            leftLabel = "Ajustes — Material 3",
            rightLabel = "Ajustes — iOS 26 Liquid Glass",
            targetFile = File(outDir, "settings_side_by_side.png")
        )

        // Close-up focalizado en la zona inferior donde el contenido pasa por debajo de la barra
        val cropTop = 1350
        val cropHeight = 890
        val navCropM3 = Bitmap.createBitmap(contentUnderNavM3, 0, cropTop, contentUnderNavM3.width, cropHeight)
        val navCropIos = Bitmap.createBitmap(contentUnderNavIos, 0, cropTop, contentUnderNavIos.width, cropHeight)

        saveSideBySide(
            left = navCropM3,
            right = navCropIos,
            leftLabel = "Barra inferior — Material 3 (Contenido pasando debajo)",
            rightLabel = "Barra inferior — iOS 26 Liquid Glass (Contenido pasando debajo)",
            targetFile = File(outDir, "bottom_nav_content_underneath.png")
        )

        // Sincronizar automáticamente en la carpeta de documentación para el PR
        val docsDir = File("../docs/screenshots/ui-variants")
        if (docsDir.exists() || docsDir.mkdirs()) {
            File(outDir, "dashboard_side_by_side.png").copyTo(File(docsDir, "dashboard_side_by_side.png"), overwrite = true)
            File(outDir, "transactions_side_by_side.png").copyTo(File(docsDir, "transactions_side_by_side.png"), overwrite = true)
            File(outDir, "settings_side_by_side.png").copyTo(File(docsDir, "settings_side_by_side.png"), overwrite = true)
            File(outDir, "bottom_nav_content_underneath.png").copyTo(File(docsDir, "bottom_nav_content_underneath.png"), overwrite = true)
        }
    }

    // Compara pixel a pixel con un muestreo cada 4 (suficiente para detectar un
    // cambio de tema completo y mucho más barato que recorrer el bitmap entero).
    // Exige además que ninguna de las dos sea un lienzo de un solo color, que es
    // como se ve una pantalla que no renderizó nada.
    private fun assertDiffer(left: Bitmap, right: Bitmap, screen: String) {
        assertTrue(left.width > 0 && left.height > 0, "$screen: Material 3 renderizó vacío")
        assertTrue(right.width > 0 && right.height > 0, "$screen: iOS renderizó vacío")
        assertTrue(!isBlank(left), "$screen: la captura Material 3 es de un solo color")
        assertTrue(!isBlank(right), "$screen: la captura iOS es de un solo color")

        var distintos = 0
        var total = 0
        val w = minOf(left.width, right.width)
        val h = minOf(left.height, right.height)
        for (x in 0 until w step 4) {
            for (y in 0 until h step 4) {
                total++
                if (left.getPixel(x, y) != right.getPixel(x, y)) distintos++
            }
        }

        val proporcion = distintos.toDouble() / total
        assertTrue(
            proporcion > 0.02,
            "$screen: las dos variantes renderizaron casi igual (${"%.4f".format(proporcion)} de píxeles distintos). " +
                "Probablemente LocalUiVariant no se está propagando."
        )
    }

    private fun isBlank(bitmap: Bitmap): Boolean {
        val first = bitmap.getPixel(0, 0)
        for (x in 0 until bitmap.width step 8) {
            for (y in 0 until bitmap.height step 8) {
                if (bitmap.getPixel(x, y) != first) return false
            }
        }
        return true
    }

    private fun renderScreenToBitmap(
        variant: UiVariant,
        content: @Composable () -> Unit
    ): Bitmap {
        val controller = Robolectric.buildActivity(ComponentActivity::class.java)
        controller.setup()
        val activity = controller.get()

        val composeView = ComposeView(activity).apply {
            setContent {
                FinancePyTheme(uiVariant = variant) {
                    content()
                }
            }
        }
        activity.setContentView(composeView)

        val width = 1080
        val height = 2240
        val widthSpec = View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY)
        val heightSpec = View.MeasureSpec.makeMeasureSpec(height, View.MeasureSpec.EXACTLY)

        repeat(4) {
            shadowOf(Looper.getMainLooper()).idle()
            composeView.measure(widthSpec, heightSpec)
            composeView.layout(0, 0, width, height)
        }

        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        composeView.draw(canvas)
        controller.pause().stop().destroy()
        return bitmap
    }

    private fun saveSideBySide(
        left: Bitmap,
        right: Bitmap,
        leftLabel: String,
        rightLabel: String,
        targetFile: File
    ) {
        val padding = 32
        val headerHeight = 96
        val totalWidth = left.width + right.width + padding * 3
        val totalHeight = maxOf(left.height, right.height) + headerHeight + padding * 2

        val combined = Bitmap.createBitmap(totalWidth, totalHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(combined)
        canvas.drawColor(Color.parseColor("#0F172A"))

        val titlePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = Color.WHITE
            textSize = 40f
            textAlign = Paint.Align.CENTER
            isFakeBoldText = true
        }

        val leftCenterX = padding + left.width / 2f
        val rightCenterX = padding * 2 + left.width + right.width / 2f
        val baselineY = padding + 56f

        canvas.drawText(leftLabel, leftCenterX, baselineY, titlePaint)
        canvas.drawText(rightLabel, rightCenterX, baselineY, titlePaint)

        val topY = (padding + headerHeight).toFloat()
        canvas.drawBitmap(left, padding.toFloat(), topY, null)
        canvas.drawBitmap(right, (padding * 2 + left.width).toFloat(), topY, null)

        FileOutputStream(targetFile).use { out ->
            combined.compress(Bitmap.CompressFormat.PNG, 95, out)
        }
    }
}

