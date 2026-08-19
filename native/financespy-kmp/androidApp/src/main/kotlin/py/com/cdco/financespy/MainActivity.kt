package py.com.cdco.financespy

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.lifecycleScope
import kotlinx.coroutines.launch
import py.com.cdco.financespy.auth.AndroidTokenStorage
import py.com.cdco.financespy.auth.AuthRepository
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.db.buildDatabase
import py.com.cdco.financespy.db.initDatabaseBuilder
import py.com.cdco.financespy.network.ApiClient
import py.com.cdco.financespy.screens.DashboardViewModel
import py.com.cdco.financespy.screens.TransactionsViewModel
import py.com.cdco.financespy.sync.SyncEngine
import py.com.cdco.financespy.sync.currentIsoDate

class MainActivity : ComponentActivity() {
    private val isLoggedIn = mutableStateOf<Boolean?>(null)
    private lateinit var authRepository: AuthRepository
    private lateinit var dashboardViewModel: DashboardViewModel
    private lateinit var transactionsViewModel: TransactionsViewModel

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        initDatabaseBuilder(applicationContext)
        val tokenStorage = AndroidTokenStorage(applicationContext)
        val httpClient = ApiClient.create(tokenStorage)
        authRepository = AuthRepository(httpClient, tokenStorage)
        val api = FinancePyApi(httpClient)
        val database = buildDatabase()
        val syncEngine = SyncEngine(
            api = api,
            accountDao = database.accountDao(),
            entryDao = database.entryDao(),
            transactionDao = database.transactionDao(),
            currentDateProvider = { currentIsoDate() }
        )
        dashboardViewModel = DashboardViewModel(
            scope = lifecycleScope,
            syncEngine = syncEngine,
            api = api,
            accountDao = database.accountDao(),
            entryDao = database.entryDao()
        )
        transactionsViewModel = TransactionsViewModel(
            scope = lifecycleScope,
            entryDao = database.entryDao()
        )

        lifecycleScope.launch {
            isLoggedIn.value = authRepository.isLoggedIn()
        }

        handleOAuthRedirect(intent)

        setContent {
            App(
                isLoggedIn = isLoggedIn.value,
                onLoginClick = {
                    val url = authRepository.buildAuthorizationUrl()
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                },
                dashboardViewModelFactory = { dashboardViewModel },
                transactionsViewModelFactory = { transactionsViewModel }
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
            authRepository.exchangeCode(code).onSuccess {
                isLoggedIn.value = true
            }
        }
    }
}
