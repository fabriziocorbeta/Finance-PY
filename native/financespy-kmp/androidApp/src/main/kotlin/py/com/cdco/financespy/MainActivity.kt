package py.com.cdco.financespy

import android.content.Intent
import android.util.Log
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.mutableStateOf
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import py.com.cdco.financespy.auth.AndroidTokenStorage
import py.com.cdco.financespy.auth.AuthRepository
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.db.buildDatabase
import py.com.cdco.financespy.db.initDatabaseBuilder
import py.com.cdco.financespy.network.ApiClient
import py.com.cdco.financespy.screens.AccountDetailViewModel
import py.com.cdco.financespy.screens.BudgetAllocationEditorViewModel
import py.com.cdco.financespy.screens.BudgetDashboardViewModel
import py.com.cdco.financespy.screens.DashboardViewModel
import py.com.cdco.financespy.screens.GoalDetailViewModel
import py.com.cdco.financespy.screens.OnboardingViewModel
import py.com.cdco.financespy.screens.GoalFormViewModel
import py.com.cdco.financespy.screens.GoalsListViewModel
import py.com.cdco.financespy.screens.ProductFormViewModel
import py.com.cdco.financespy.screens.ProductsListViewModel
import py.com.cdco.financespy.screens.PurchaseOrderDetailViewModel
import py.com.cdco.financespy.screens.PurchaseOrderFormViewModel
import py.com.cdco.financespy.screens.PurchaseOrdersListViewModel
import py.com.cdco.financespy.screens.ReceivableDetailViewModel
import py.com.cdco.financespy.screens.FleetListViewModel
import py.com.cdco.financespy.screens.FleetVehicleDetailViewModel
import py.com.cdco.financespy.screens.ReceivableFormViewModel
import py.com.cdco.financespy.screens.ReceivablesListViewModel
import py.com.cdco.financespy.screens.ReportsViewModel
import py.com.cdco.financespy.screens.SaleDetailViewModel
import py.com.cdco.financespy.screens.SaleFormViewModel
import py.com.cdco.financespy.screens.SalesListViewModel
import py.com.cdco.financespy.screens.RuleDetailViewModel
import py.com.cdco.financespy.screens.RuleFormViewModel
import py.com.cdco.financespy.screens.RulesListViewModel
import py.com.cdco.financespy.screens.SettingsViewModel
import py.com.cdco.financespy.screens.TransactionFormViewModel
import py.com.cdco.financespy.screens.TransactionsViewModel
import py.com.cdco.financespy.sync.SyncEngine
import py.com.cdco.financespy.sync.currentIsoDate
import py.com.cdco.financespy.wallet.WalletCaptureHandler

class MainActivity : ComponentActivity() {
    companion object {
        var onCreateStartTime: Long = 0L
    }

    private val isLoggedIn = mutableStateOf<Boolean?>(null)
    private val needsOnboarding = mutableStateOf(false)

    private val tokenStorage by lazy { AndroidTokenStorage(applicationContext) }
    private val httpClient by lazy { ApiClient.create(tokenStorage) }
    private val authRepository by lazy { AuthRepository(httpClient, tokenStorage) }
    private val api by lazy { FinancePyApi(httpClient) }
    private val database by lazy { buildDatabase() }
    private val syncEngine by lazy {
        SyncEngine(
            api = api,
            accountDao = database.accountDao(),
            entryDao = database.entryDao(),
            transactionDao = database.transactionDao(),
            ruleDao = database.ruleDao(),
            ruleRunDao = database.ruleRunDao(),
            goalDao = database.goalDao(),
            receivableDao = database.receivableDao(),
            currentDateProvider = { currentIsoDate() }
        )
    }
    private val dashboardViewModel by lazy {
        DashboardViewModel(
            scope = lifecycleScope,
            syncEngine = syncEngine,
            api = api,
            accountDao = database.accountDao(),
            entryDao = database.entryDao()
        )
    }
    private val budgetDashboardViewModel by lazy {
        BudgetDashboardViewModel(
            scope = lifecycleScope,
            api = api
        )
    }
    private val transactionsViewModel by lazy {
        TransactionsViewModel(
            scope = lifecycleScope,
            api = api
        )
    }
    private val rulesListViewModel by lazy {
        RulesListViewModel(
            scope = lifecycleScope,
            ruleDao = database.ruleDao(),
            api = api
        )
    }
    private val goalsListViewModel by lazy {
        GoalsListViewModel(
            scope = lifecycleScope,
            api = api,
            goalDao = database.goalDao()
        )
    }
    private val receivablesListViewModel by lazy {
        ReceivablesListViewModel(
            scope = lifecycleScope,
            api = api,
            receivableDao = database.receivableDao()
        )
    }
    private val productsListViewModel by lazy {
        ProductsListViewModel(
            api = api
        )
    }
    private val salesListViewModel by lazy {
        SalesListViewModel(
            api = api
        )
    }
    private val purchaseOrdersListViewModel by lazy {
        PurchaseOrdersListViewModel(
            api = api
        )
    }
    private val fleetListViewModel by lazy {
        FleetListViewModel(
            scope = lifecycleScope,
            api = api
        )
    }
    private val settingsViewModel by lazy {
        SettingsViewModel(
            scope = lifecycleScope,
            api = api,
            authRepository = authRepository
        )
    }
    private val reportsViewModel by lazy {
        ReportsViewModel(
            scope = lifecycleScope,
            syncEngine = syncEngine,
            api = api
        )
    }
    private val onboardingViewModel by lazy {
        OnboardingViewModel(
            scope = lifecycleScope,
            api = api
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        splashScreen.setKeepOnScreenCondition { isLoggedIn.value == null }

        onCreateStartTime = System.currentTimeMillis()
        Log.d("ColdStartProfile", "[Optimized] onCreate STARTED at $onCreateStartTime ms")
        super.onCreate(savedInstanceState)

        initDatabaseBuilder(applicationContext)

        lifecycleScope.launch(Dispatchers.IO) {
            val tAuthStart = System.currentTimeMillis()
            val loggedIn = authRepository.isLoggedIn()
            var onboardingNeeded = false
            if (loggedIn) {
                try {
                    val settings = api.fetchFamilySettings()
                    onboardingNeeded = settings.current_user?.needs_onboarding == true
                } catch (e: Exception) {
                    onboardingNeeded = false
                }
            }
            val tAuthEnd = System.currentTimeMillis()
            Log.d("ColdStartProfile", "[Optimized] Auth check on IO completed in ${tAuthEnd - tAuthStart} ms (isLoggedIn=$loggedIn, needsOnboarding=$onboardingNeeded)")
            withContext(Dispatchers.Main) {
                needsOnboarding.value = onboardingNeeded
                isLoggedIn.value = loggedIn
            }
        }

        handleOAuthRedirect(intent)

        val tSetContent = System.currentTimeMillis()
        Log.d("ColdStartProfile", "[Optimized] Calling setContent at +${tSetContent - onCreateStartTime} ms from onCreate")

        setContent {
            App(
                isLoggedIn = isLoggedIn.value,
                api = api,
                needsOnboarding = needsOnboarding.value,
                onLoginClick = {
                    val url = authRepository.buildAuthorizationUrl()
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                },
                onLoggedOut = {
                    isLoggedIn.value = false
                },
                onboardingViewModelFactory = { onboardingViewModel },
                dashboardViewModelFactory = { dashboardViewModel },
                budgetDashboardViewModelFactory = { budgetDashboardViewModel },
                budgetAllocationEditorViewModelFactory = { budgetId ->
                    BudgetAllocationEditorViewModel(
                        scope = lifecycleScope,
                        api = api,
                        budgetId = budgetId
                    )
                },
                transactionsViewModelFactory = { transactionsViewModel },
                transactionFormViewModelFactory = { transactionId ->
                    TransactionFormViewModel(scope = lifecycleScope, api = api, transactionId = transactionId)
                },
                rulesListViewModelFactory = { rulesListViewModel },
                ruleDetailViewModelFactory = { ruleId ->
                    RuleDetailViewModel(
                        scope = lifecycleScope, ruleId = ruleId, api = api,
                        ruleDao = database.ruleDao(), ruleRunDao = database.ruleRunDao()
                    )
                },
                ruleFormViewModelFactory = { ruleId ->
                    RuleFormViewModel(scope = lifecycleScope, ruleId = ruleId, api = api)
                },
                goalsListViewModelFactory = { goalsListViewModel },
                goalDetailViewModelFactory = { goalId ->
                    GoalDetailViewModel(
                        scope = lifecycleScope, goalId = goalId, api = api, goalDao = database.goalDao()
                    )
                },
                goalFormViewModelFactory = { goalId ->
                    GoalFormViewModel(
                        scope = lifecycleScope, goalId = goalId, api = api,
                        goalDao = database.goalDao(), accountDao = database.accountDao()
                    )
                },
                receivablesListViewModelFactory = { receivablesListViewModel },
                receivableDetailViewModelFactory = { receivableId ->
                    ReceivableDetailViewModel(
                        scope = lifecycleScope, receivableId = receivableId, api = api,
                        receivableDao = database.receivableDao()
                    )
                },
                receivableFormViewModelFactory = { receivableId ->
                    ReceivableFormViewModel(
                        scope = lifecycleScope, receivableId = receivableId, api = api,
                        receivableDao = database.receivableDao()
                    )
                },
                productsListViewModelFactory = { productsListViewModel },
                productFormViewModelFactory = { productId ->
                    ProductFormViewModel(productId = productId, api = api)
                },
                salesListViewModelFactory = { salesListViewModel },
                saleDetailViewModelFactory = { saleId ->
                    SaleDetailViewModel(saleId = saleId, api = api)
                },
                saleFormViewModelFactory = { saleId ->
                    SaleFormViewModel(saleId = saleId, api = api)
                },
                purchaseOrdersListViewModelFactory = { purchaseOrdersListViewModel },
                purchaseOrderDetailViewModelFactory = { poId ->
                    PurchaseOrderDetailViewModel(purchaseOrderId = poId, api = api)
                },
                purchaseOrderFormViewModelFactory = { poId ->
                    PurchaseOrderFormViewModel(purchaseOrderId = poId, api = api)
                },
                fleetListViewModelFactory = { fleetListViewModel },
                fleetVehicleDetailViewModelFactory = { vehicleId ->
                    FleetVehicleDetailViewModel(
                        scope = lifecycleScope,
                        vehicleId = vehicleId,
                        api = api
                    )
                },
                accountDetailViewModelFactory = { accountId ->
                    AccountDetailViewModel(
                        scope = lifecycleScope,
                        accountId = accountId,
                        accountDao = database.accountDao(),
                        entryDao = database.entryDao(),
                        api = api
                    )
                },
                settingsViewModelFactory = { settingsViewModel },
                reportsViewModelFactory = { reportsViewModel },
                onOpenNotificationSettings = {
                    val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                },
                onShareFile = { bytes, filename, mimeType ->
                    shareFile(bytes, filename, mimeType)
                }
            )
        }
    }

    private fun shareFile(bytes: ByteArray, filename: String, mimeType: String) {
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val file = java.io.File(cacheDir, filename)
                file.writeBytes(bytes)
                val uri = androidx.core.content.FileProvider.getUriForFile(
                    this@MainActivity,
                    "$packageName.fileprovider",
                    file
                )
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = mimeType
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                withContext(Dispatchers.Main) {
                    startActivity(Intent.createChooser(intent, "Compartir archivo"))
                }
            } catch (e: Exception) {
                Log.e("FinancePYShare", "Error sharing file", e)
            }
        }
    }

    override fun onResume() {
        super.onResume()
        WalletCaptureHandler.retryPending(applicationContext)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleOAuthRedirect(intent)
    }

    private fun handleOAuthRedirect(intent: Intent) {
        val uri = intent.data ?: return
        if (uri.scheme != "financespy" || uri.host != "oauth") return
        val code = uri.getQueryParameter("code") ?: return
        lifecycleScope.launch {
            authRepository.exchangeCode(code)
                .onSuccess {
                    val settings = try { api.fetchFamilySettings() } catch (e: Exception) { null }
                    needsOnboarding.value = settings?.current_user?.needs_onboarding == true
                    isLoggedIn.value = true
                }
                .onFailure { e -> Log.e("FinancePYAuth", "exchangeCode failed", e) }
        }
    }
}
