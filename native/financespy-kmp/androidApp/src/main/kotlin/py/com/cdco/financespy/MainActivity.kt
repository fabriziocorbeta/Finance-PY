package py.com.cdco.financespy

import android.content.Intent
import android.util.Log
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.material.Button
import androidx.compose.material.Text
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.fragment.app.FragmentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.mutableStateOf
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import py.com.cdco.financespy.auth.AndroidTokenStorage
import py.com.cdco.financespy.auth.AuthRepository
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.cache.AndroidDashboardCache
import py.com.cdco.financespy.db.buildDatabase
import py.com.cdco.financespy.db.initDatabaseBuilder
import py.com.cdco.financespy.navigation.AndroidNavPreferences
import py.com.cdco.financespy.network.ApiClient
import py.com.cdco.financespy.security.AndroidSecurityPreferences
import py.com.cdco.financespy.security.OwnerScope
import py.com.cdco.financespy.screens.AccountDetailViewModel
import py.com.cdco.financespy.screens.AccountFormViewModel
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
import py.com.cdco.financespy.screens.UpayImportViewModel
import py.com.cdco.financespy.screens.TransactionFormViewModel
import py.com.cdco.financespy.screens.TransactionsViewModel
import py.com.cdco.financespy.sync.SyncEngine
import py.com.cdco.financespy.sync.currentIsoDate
import py.com.cdco.financespy.wallet.WalletCaptureHandler
import android.view.MotionEvent

class MainActivity : FragmentActivity() {
    companion object {
        var onCreateStartTime: Long = 0L
    }

    private val isLoggedIn = mutableStateOf<Boolean?>(null)
    private val needsOnboarding = mutableStateOf(false)
    private val isBiometricAuthenticated = mutableStateOf(false)

    // Set by the inactivity timeout. Forces the local device-credential gate
    // even if the biometric toggle is off; cleared on successful unlock.
    private val inactivityLocked = mutableStateOf(false)
    private val biometricUnavailable = mutableStateOf(false)
    private val securityPreferences by lazy { AndroidSecurityPreferences(applicationContext) }
    private val biometricLockEnabled = mutableStateOf(false)
    private val screenCaptureBlockEnabled = mutableStateOf(true)

    // App-level (not Activity-level) observer: fires only when the whole app
    // truly leaves the foreground, not on rotation/config-change recreation
    // (ProcessLifecycleOwner debounces those). Re-arms the gate so returning
    // from background always re-prompts, instead of relying on Activity
    // recreation which doesn't happen when the Activity is merely stopped.
    private val processLifecycleObserver = object : DefaultLifecycleObserver {
        override fun onStop(owner: LifecycleOwner) {
            isBiometricAuthenticated.value = false
        }
    }

    // registerForActivityResult debe llamarse antes de que la Activity entre
    // en STARTED -- por eso es una property de clase (eager), no algo armado
    // dentro de onCreate ni lazy.
    private var upayCsvPickedCallback: ((ByteArray, String) -> Unit)? = null
    private val upayCsvPickerLauncher = registerForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        uri?.let { handleUpayCsvPicked(it) }
    }

    private val tokenStorage by lazy { AndroidTokenStorage(applicationContext) }
    private val navPreferences by lazy { AndroidNavPreferences(applicationContext) }
    private val dashboardCache by lazy { AndroidDashboardCache(applicationContext) }
    private val offlineStore by lazy { py.com.cdco.financespy.cache.AndroidOfflineStore(applicationContext) }
    private val pendingCaptureStore by lazy { py.com.cdco.financespy.wallet.PendingCaptureStore(applicationContext) }
    private val httpClient by lazy { ApiClient.create(tokenStorage) }
    private val authRepository by lazy {
        AuthRepository(
            httpClient,
            tokenStorage,
            wipeLocalData = {
                // Room forbids main-thread queries; logout() runs on
                // lifecycleScope (Main), so hop to IO for the wipe.
                withContext(Dispatchers.IO) {
                    database.clearAllTables()
                    offlineStore.wipeAll()
                    dashboardCache.wipeAll()
                    pendingCaptureStore.wipeAll()
                    OwnerScope.clear(applicationContext)
                    // Deliberately NOT wiped: securityPreferences (biometric
                    // lock + screen-capture-block toggles). Those are
                    // device-level security posture, not this user's data --
                    // clearing them would silently weaken the lock for
                    // whoever uses the device next, which is the opposite of
                    // what a "wipe on logout" is supposed to achieve.
                }
            }
        )
    }
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
    private val outbox by lazy {
        py.com.cdco.financespy.sync.OfflineOutbox(
            api = api,
            store = offlineStore,
            now = { System.currentTimeMillis() },
            onFlushed = { syncEngine.syncAll() }
        )
    }
    private val dashboardViewModel by lazy {
        DashboardViewModel(
            scope = lifecycleScope,
            syncEngine = syncEngine,
            api = api,
            accountDao = database.accountDao(),
            entryDao = database.entryDao(),
            dashboardCache = dashboardCache
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
            api = api,
            entryDao = database.entryDao(),
            transactionDao = database.transactionDao(),
            accountDao = database.accountDao(),
            outbox = outbox
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
            authRepository = authRepository,
            outbox = outbox
        )
    }
    private val reportsViewModel by lazy {
        ReportsViewModel(
            scope = lifecycleScope,
            syncEngine = syncEngine,
            api = api,
            store = offlineStore
        )
    }
    private val onboardingViewModel by lazy {
        OnboardingViewModel(
            scope = lifecycleScope,
            api = api
        )
    }

    private val appLifecycleObserver by lazy {
        AppLifecycleObserver(applicationContext) {
            inactivityLocked.value = true
            isBiometricAuthenticated.value = false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val splashScreen = installSplashScreen()
        splashScreen.setKeepOnScreenCondition { isLoggedIn.value == null }

        onCreateStartTime = System.currentTimeMillis()
        Log.d("ColdStartProfile", "[Optimized] onCreate STARTED at $onCreateStartTime ms")
        super.onCreate(savedInstanceState)

        screenCaptureBlockEnabled.value = securityPreferences.isScreenCaptureBlockEnabled()
        applyScreenCaptureBlock(screenCaptureBlockEnabled.value)
        ProcessLifecycleOwner.get().lifecycle.addObserver(processLifecycleObserver)
        biometricLockEnabled.value = securityPreferences.isBiometricLockEnabled()

        initDatabaseBuilder(applicationContext)

        ProcessLifecycleOwner.get().lifecycle.addObserver(appLifecycleObserver)

        // Deliver queued offline writes: on start/resume and every 30s while
        // the app is visible. flush() stops at the first unreachable result.
        lifecycleScope.launch {
            repeatOnLifecycle(androidx.lifecycle.Lifecycle.State.STARTED) {
                while (true) {
                    if (isLoggedIn.value == true) runCatching { outbox.flush() }
                    kotlinx.coroutines.delay(30_000)
                }
            }
        }

        lifecycleScope.launch(Dispatchers.IO) {
            val tAuthStart = System.currentTimeMillis()
            val loggedIn = authRepository.isLoggedIn()
            var onboardingNeeded = false
            if (loggedIn) {
                try {
                    // Cap it: with the server down the client's 30s connect
                    // timeout would otherwise pin the splash for 30s.
                    val settings = withTimeoutOrNull(4_000L) { api.fetchFamilySettings() }
                    onboardingNeeded = settings?.current_user?.needs_onboarding == true
                    // Data already fetched above, just reusing it: record who
                    // this device's local caches/outbox belong to now, so a
                    // different family logging in on the same device later
                    // doesn't see this one's offline data (see OwnerScope).
                    settings?.id?.let { OwnerScope.setCurrentOwnerId(applicationContext, it) }
                } catch (e: Exception) {
                    onboardingNeeded = false
                }
            }
            val tAuthEnd = System.currentTimeMillis()
            Log.d("ColdStartProfile", "[Optimized] Auth check on IO completed in ${tAuthEnd - tAuthStart} ms (isLoggedIn=$loggedIn, needsOnboarding=$onboardingNeeded)")
            withContext(Dispatchers.Main) {
                needsOnboarding.value = onboardingNeeded
                isLoggedIn.value = loggedIn
                appLifecycleObserver.isLoggedIn = loggedIn
                if (loggedIn) {
                    appLifecycleObserver.resetClock()
                }
            }
        }

        handleOAuthRedirect(intent)

        val tSetContent = System.currentTimeMillis()
        Log.d("ColdStartProfile", "[Optimized] Calling setContent at +${tSetContent - onCreateStartTime} ms from onCreate")

        setContent {
            if (isLoggedIn.value == true && (biometricLockEnabled.value || inactivityLocked.value) && !isBiometricAuthenticated.value) {
                if (biometricUnavailable.value) {
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("Configure un bloqueo de pantalla (PIN, patrón o huella) en su dispositivo para usar FinancePY.")
                            Button(onClick = {
                                startActivity(Intent(android.provider.Settings.ACTION_SECURITY_SETTINGS))
                            }) {
                                Text("Abrir configuración")
                            }
                        }
                    }
                } else {
                    LaunchedEffect(Unit) {
                        showBiometricPrompt()
                    }
                    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                        Button(onClick = { showBiometricPrompt() }) {
                            Text("Desbloquear")
                        }
                    }
                }
            } else {
                App(
                isLoggedIn = isLoggedIn.value,
                api = api,
                navPreferences = navPreferences,
                needsOnboarding = needsOnboarding.value,
                onLoginClick = {
                    val url = authRepository.buildAuthorizationUrl()
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                },
                onLoggedOut = {
                    isLoggedIn.value = false
                    appLifecycleObserver.isLoggedIn = false
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
                    TransactionFormViewModel(scope = lifecycleScope, api = api, transactionId = transactionId, outbox = outbox,
                        entryDao = database.entryDao(), transactionDao = database.transactionDao())
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
                        scope = lifecycleScope, goalId = goalId, api = api, goalDao = database.goalDao(),
                        outbox = outbox
                    )
                },
                goalFormViewModelFactory = { goalId ->
                    GoalFormViewModel(
                        scope = lifecycleScope, goalId = goalId, api = api,
                        goalDao = database.goalDao(), accountDao = database.accountDao(),
                        outbox = outbox
                    )
                },
                receivablesListViewModelFactory = { receivablesListViewModel },
                receivableDetailViewModelFactory = { receivableId ->
                    ReceivableDetailViewModel(
                        scope = lifecycleScope, receivableId = receivableId, api = api,
                        receivableDao = database.receivableDao(),
                        outbox = outbox
                    )
                },
                receivableFormViewModelFactory = { receivableId ->
                    ReceivableFormViewModel(
                        scope = lifecycleScope, receivableId = receivableId, api = api,
                        receivableDao = database.receivableDao(),
                        outbox = outbox
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
                    SaleFormViewModel(saleId = saleId, api = api, accountDao = database.accountDao())
                },
                purchaseOrdersListViewModelFactory = { purchaseOrdersListViewModel },
                purchaseOrderDetailViewModelFactory = { poId ->
                    PurchaseOrderDetailViewModel(purchaseOrderId = poId, api = api)
                },
                purchaseOrderFormViewModelFactory = { poId ->
                    PurchaseOrderFormViewModel(purchaseOrderId = poId, api = api, accountDao = database.accountDao())
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
                accountFormViewModelFactory = {
                    AccountFormViewModel(scope = lifecycleScope, api = api, accountDao = database.accountDao())
                },
                settingsViewModelFactory = { settingsViewModel },
                isBiometricLockEnabled = biometricLockEnabled.value,
                onToggleBiometricLock = { enabled ->
                    securityPreferences.setBiometricLockEnabled(enabled)
                    biometricLockEnabled.value = enabled
                },
                isScreenCaptureBlockEnabled = screenCaptureBlockEnabled.value,
                onToggleScreenCaptureBlock = { enabled ->
                    securityPreferences.setScreenCaptureBlockEnabled(enabled)
                    screenCaptureBlockEnabled.value = enabled
                    applyScreenCaptureBlock(enabled)
                },
                reportsViewModelFactory = { reportsViewModel },
                upayImportViewModelFactory = {
                    UpayImportViewModel(scope = lifecycleScope, api = api, accountDao = database.accountDao())
                },
                onOpenNotificationSettings = {
                    val intent = Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS").apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                },
                onShareFile = { bytes, filename, mimeType ->
                    shareFile(bytes, filename, mimeType)
                },
                onPickUpayCsv = { onPicked -> pickUpayCsv(onPicked) },
                outbox = outbox
                )
            }
        }
    }


    private fun applyScreenCaptureBlock(enabled: Boolean) {
        if (enabled) {
            window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    private fun showBiometricPrompt() {
        val biometricManager = BiometricManager.from(this)
        val canAuthenticate = biometricManager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_WEAK or BiometricManager.Authenticators.DEVICE_CREDENTIAL
        )

        if (canAuthenticate == BiometricManager.BIOMETRIC_SUCCESS) {
            val executor = ContextCompat.getMainExecutor(this)
            val biometricPrompt = BiometricPrompt(this, executor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                        super.onAuthenticationSucceeded(result)
                        isBiometricAuthenticated.value = true
                        inactivityLocked.value = false
                        appLifecycleObserver.onUnlocked()
                    }
                    override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                        super.onAuthenticationError(errorCode, errString)
                    }
                })

            val promptInfo = BiometricPrompt.PromptInfo.Builder()
                .setTitle("Autenticación Requerida")
                .setSubtitle("Desbloquee para acceder a FinanceSpy")
                .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_WEAK or BiometricManager.Authenticators.DEVICE_CREDENTIAL)
                .build()

            biometricPrompt.authenticate(promptInfo)
        } else {
            // No biometric enrolled AND no device credential (PIN/pattern/password)
            // set -- fail CLOSED, not open. A financial app must never let an
            // unsecured device through the gate silently.
            if (biometricLockEnabled.value) {
                biometricUnavailable.value = true
            } else {
                // Lock came only from the inactivity timeout and the device has
                // no screen lock at all: nothing to verify against, and the
                // user never opted into the strict gate. Don't trap them.
                isBiometricAuthenticated.value = true
                inactivityLocked.value = false
                appLifecycleObserver.onUnlocked()
            }
        }
    }

    override fun dispatchTouchEvent(ev: MotionEvent?): Boolean {
        if (isLoggedIn.value == true) {
            val locked = appLifecycleObserver.updateInteractionTime()
            if (locked) {
                return true
            }
        }
        return super.dispatchTouchEvent(ev)
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

    private fun pickUpayCsv(onPicked: (ByteArray, String) -> Unit) {
        upayCsvPickedCallback = onPicked
        upayCsvPickerLauncher.launch("*/*")
    }

    private fun handleUpayCsvPicked(uri: Uri) {
        val callback = upayCsvPickedCallback ?: return
        lifecycleScope.launch(Dispatchers.IO) {
            try {
                val fileName = contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (cursor.moveToFirst() && nameIndex >= 0) cursor.getString(nameIndex) else null
                } ?: uri.lastPathSegment ?: "upay.csv"

                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() }
                    ?: throw IllegalStateException("No se pudo leer el archivo seleccionado")

                withContext(Dispatchers.Main) {
                    callback(bytes, fileName)
                }
            } catch (e: Exception) {
                Log.e("FinancePYUpayImport", "Error reading picked CSV", e)
            } finally {
                upayCsvPickedCallback = null
            }
        }
    }

    override fun onResume() {
        super.onResume()
        WalletCaptureHandler.retryPending(applicationContext)
        // Re-check in case the user just set up a screen lock from the
        // "Abrir configuración" redirect -- otherwise they'd be stuck on
        // that screen forever even after fixing it.
        if (biometricUnavailable.value) {
            biometricUnavailable.value = false
        }
    }

    override fun onDestroy() {
        ProcessLifecycleOwner.get().lifecycle.removeObserver(processLifecycleObserver)
        ProcessLifecycleOwner.get().lifecycle.removeObserver(appLifecycleObserver)
        appLifecycleObserver.cleanUp()
        super.onDestroy()
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
        val state = uri.getQueryParameter("state")
        lifecycleScope.launch {
            authRepository.exchangeCode(code, state)
                .onSuccess {
                    val settings = try { api.fetchFamilySettings() } catch (e: Exception) { null }
                    needsOnboarding.value = settings?.current_user?.needs_onboarding == true
                    settings?.id?.let { OwnerScope.setCurrentOwnerId(applicationContext, it) }
                    isLoggedIn.value = true
                    appLifecycleObserver.isLoggedIn = true
                    appLifecycleObserver.resetClock()
                }
                .onFailure { e -> Log.e("FinancePYAuth", "exchangeCode failed", e) }
        }
    }
}
