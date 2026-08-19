package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.BalanceSheetResponse
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity
import py.com.cdco.financespy.sync.SyncEngine

data class DashboardState(
    val accounts: List<AccountEntity> = emptyList(),
    val recentEntries: List<EntryEntity> = emptyList(),
    val balanceSheet: BalanceSheetResponse? = null,
    val isSyncing: Boolean = false,
    val syncError: String? = null
)

class DashboardViewModel(
    private val scope: CoroutineScope,
    private val syncEngine: SyncEngine,
    private val api: FinancePyApi,
    accountDao: AccountDao,
    entryDao: EntryDao
) {
    private val _state = MutableStateFlow(DashboardState())
    val state: StateFlow<DashboardState> = _state

    init {
        combine(accountDao.observeAll(), entryDao.observeRecent(20)) { accounts, entries ->
            _state.value.copy(accounts = accounts, recentEntries = entries)
        }.onEach { _state.value = it }.launchIn(scope)

        refresh()
    }

    fun refresh() {
        scope.launch {
            _state.value = _state.value.copy(isSyncing = true, syncError = null)
            syncEngine.syncAll()
                .onSuccess {
                    val balanceSheet = runCatching { api.fetchBalanceSheet() }.getOrNull()
                    _state.value = _state.value.copy(isSyncing = false, balanceSheet = balanceSheet)
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(isSyncing = false, syncError = e.message ?: "Error de sincronización")
                }
        }
    }
}
