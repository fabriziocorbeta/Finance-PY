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
import py.com.cdco.financespy.screens.DashboardViewModel
import py.com.cdco.financespy.screens.GoalDetailViewModel
import py.com.cdco.financespy.screens.GoalFormViewModel
import py.com.cdco.financespy.screens.GoalsListViewModel
import py.com.cdco.financespy.screens.RuleDetailViewModel
import py.com.cdco.financespy.screens.RuleFormViewModel
import py.com.cdco.financespy.screens.RulesListViewModel
import py.com.cdco.financespy.screens.TransactionsViewModel
import py.com.cdco.financespy.sync.SyncEngine
import py.com.cdco.financespy.sync.currentIsoDate

class MainActivity : ComponentActivity() {
    companion object {
        var onCreateStartTime: Long = 0L
    }

    private val isLoggedIn = mutableStateOf<Boolean?>(null)

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
    private val transactionsViewModel by lazy {
        TransactionsViewModel(
            scope = lifecycleScope,
            entryDao = database.entryDao()
        )
    }
    private val rulesListViewModel by lazy {
        RulesListViewModel(
            scope = lifecycleScope,
            ruleDao = database.ruleDao()
        )
    }
    private val goalsListViewModel by lazy {
        GoalsListViewModel(
            scope = lifecycleScope,
            goalDao = database.goalDao()
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
            val tAuthEnd = System.currentTimeMillis()
            Log.d("ColdStartProfile", "[Optimized] Auth check on IO completed in ${tAuthEnd - tAuthStart} ms (isLoggedIn=$loggedIn)")
            withContext(Dispatchers.Main) {
                isLoggedIn.value = loggedIn
            }
        }

        handleOAuthRedirect(intent)

        val tSetContent = System.currentTimeMillis()
        Log.d("ColdStartProfile", "[Optimized] Calling setContent at +${tSetContent - onCreateStartTime} ms from onCreate")

        setContent {
            App(
                isLoggedIn = isLoggedIn.value,
                onLoginClick = {
                    val url = authRepository.buildAuthorizationUrl()
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                },
                dashboardViewModelFactory = { dashboardViewModel },
                transactionsViewModelFactory = { transactionsViewModel },
                rulesListViewModelFactory = { rulesListViewModel },
                ruleDetailViewModelFactory = { ruleId ->
                    RuleDetailViewModel(
                        scope = lifecycleScope, ruleId = ruleId, api = api,
                        ruleDao = database.ruleDao(), ruleRunDao = database.ruleRunDao()
                    )
                },
                ruleFormViewModelFactory = { ruleId ->
                    RuleFormViewModel(scope = lifecycleScope, ruleId = ruleId, api = api, ruleDao = database.ruleDao())
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
                accountDetailViewModelFactory = { accountId ->
                    AccountDetailViewModel(
                        scope = lifecycleScope,
                        accountId = accountId,
                        accountDao = database.accountDao(),
                        entryDao = database.entryDao()
                    )
                }
            )
        }
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
                .onSuccess { isLoggedIn.value = true }
                .onFailure { e -> Log.e("FinancePYAuth", "exchangeCode failed", e) }
        }
    }
}
