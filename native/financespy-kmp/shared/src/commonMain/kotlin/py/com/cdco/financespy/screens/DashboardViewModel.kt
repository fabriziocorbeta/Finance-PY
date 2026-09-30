package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
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
            // The dashboard comes from its own server-side endpoint
            // (api.fetchDashboard), computed from the server's own data --
            // it does not read from the local Room tables that syncAll()
            // populates. Waiting for the full local sync (accounts,
            // transactions, rules, goals, receivables) before even starting
            // the dashboard fetch only added its own latency on top for no
            // correctness reason. Run both concurrently instead.
            coroutineScope {
                val sync = async { runCatching { syncEngine.syncAll() } }
                val dashboard = async { loadDashboardInternal() }
                sync.await()
                dashboard.await()
            }
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
                val json = dashboardCacheJson.encodeToString(DashboardDto.serializer(), dto)
                dashboardCache?.save(resolvedPeriod, json)
                // loadFromCache() on a cold start always looks up
                // `selectedPeriod`, which is null until a network response
                // resolves it -- so a save under only `resolvedPeriod` (e.g.
                // "2026-09") is invisible to that lookup (keyed "default")
                // and the offline fallback never hits on the very next cold
                // start with no connectivity. Mirror the save under the
                // original request key too when they differ.
                if (period != resolvedPeriod) {
                    dashboardCache?.save(period, json)
                }
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
