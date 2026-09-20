package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.DashboardDto
import py.com.cdco.financespy.cache.DashboardCache
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.sync.SyncEngine
import py.com.cdco.financespy.utils.describeForUser
import kotlinx.coroutines.withTimeout

data class DashboardState(
    val dashboard: DashboardDto? = null,
    val selectedPeriod: String? = null,
    val isSyncing: Boolean = false,
    val syncError: String? = null,
    val isShowingCachedData: Boolean = false
)

private val dashboardCacheJson = Json { ignoreUnknownKeys = true; isLenient = true }

class DashboardViewModel(
    private val scope: CoroutineScope,
    private val syncEngine: SyncEngine,
    private val api: FinancePyApi,
    accountDao: AccountDao? = null,
    entryDao: EntryDao? = null,
    private val dashboardCache: DashboardCache? = null
) {
    private val _state = MutableStateFlow(DashboardState())
    val state: StateFlow<DashboardState> = _state.asStateFlow()

    init {
        loadFromCache()
        refresh()
    }

    private fun loadFromCache() {
        val period = _state.value.selectedPeriod
        val cachedDashboard = dashboardCache?.load(period)?.let { cachedJson ->
            runCatching { dashboardCacheJson.decodeFromString(DashboardDto.serializer(), cachedJson) }.getOrNull()
        }?.takeIf { it.period != null } // a copy without a period is a poisoned cache (empty error body)
        // Sin cache para este período: no dejar visible el dashboard del período
        // anterior con la etiqueta cambiada -- mejor volver a null/loading.
        _state.update {
            it.copy(dashboard = cachedDashboard, isShowingCachedData = cachedDashboard != null)
        }
    }

    fun selectPeriod(periodKey: String?) {
        _state.update { it.copy(selectedPeriod = periodKey) }
        loadFromCache()
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
            withTimeout(35_000L) { api.fetchDashboard(period) }.also {
                check(it.period != null) { "Respuesta inválida del servidor" }
            }
        }.onSuccess { dto ->
            val resolvedPeriod = dto.period?.key ?: period
            runCatching {
                dashboardCache?.save(resolvedPeriod, dashboardCacheJson.encodeToString(DashboardDto.serializer(), dto))
            }
            _state.update {
                it.copy(
                    isSyncing = false,
                    dashboard = dto,
                    selectedPeriod = resolvedPeriod,
                    isShowingCachedData = false
                )
            }
        }.onFailure { e ->
            _state.update {
                it.copy(
                    isSyncing = false,
                    syncError = e.describeForUser()
                )
            }
        }
    }
}
