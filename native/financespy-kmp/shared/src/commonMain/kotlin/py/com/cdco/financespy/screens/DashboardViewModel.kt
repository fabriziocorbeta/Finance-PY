package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.DashboardDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.sync.SyncEngine

data class DashboardState(
    val dashboard: DashboardDto? = null,
    val selectedPeriod: String? = null,
    val isSyncing: Boolean = false,
    val syncError: String? = null
)

class DashboardViewModel(
    private val scope: CoroutineScope,
    private val syncEngine: SyncEngine,
    private val api: FinancePyApi,
    accountDao: AccountDao? = null,
    entryDao: EntryDao? = null
) {
    private val _state = MutableStateFlow(DashboardState())
    val state: StateFlow<DashboardState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun selectPeriod(periodKey: String?) {
        _state.update { it.copy(selectedPeriod = periodKey) }
        loadDashboard()
    }

    fun refresh() {
        scope.launch {
            _state.update { it.copy(isSyncing = true, syncError = null) }
            runCatching {
                syncEngine.syncAll()
            }
            loadDashboardInternal()
        }
    }

    fun loadDashboard() {
        scope.launch {
            _state.update { it.copy(isSyncing = true, syncError = null) }
            loadDashboardInternal()
        }
    }

    private suspend fun loadDashboardInternal() {
        val period = _state.value.selectedPeriod
        runCatching {
            api.fetchDashboard(period)
        }.onSuccess { dto ->
            _state.update {
                it.copy(
                    isSyncing = false,
                    dashboard = dto,
                    selectedPeriod = dto.period?.key ?: period
                )
            }
        }.onFailure { e ->
            _state.update {
                it.copy(
                    isSyncing = false,
                    syncError = e.message ?: "Error al cargar el dashboard"
                )
            }
        }
    }
}
