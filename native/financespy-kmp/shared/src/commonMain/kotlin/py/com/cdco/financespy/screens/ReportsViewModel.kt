package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.ReportsSummaryDto
import py.com.cdco.financespy.sync.OfflineStore
import py.com.cdco.financespy.sync.SyncEngine
import py.com.cdco.financespy.utils.describeForUser
import kotlinx.coroutines.withTimeout
import kotlinx.serialization.json.Json

data class ReportsState(
    val reportsSummary: ReportsSummaryDto? = null,
    val selectedPeriodType: String = "monthly",
    val isLoading: Boolean = false,
    val isExportingCsv: Boolean = false,
    val error: String? = null,
    // Showing the last saved report because the fresh one has not arrived (or failed).
    val isShowingSavedData: Boolean = false
)

private val reportsJson = Json { ignoreUnknownKeys = true; isLenient = true }

class ReportsViewModel(
    private val scope: CoroutineScope,
    private val syncEngine: SyncEngine,
    private val api: FinancePyApi,
    private val store: OfflineStore? = null
) {
    private val _state = MutableStateFlow(ReportsState())
    val state: StateFlow<ReportsState> = _state.asStateFlow()

    init {
        showSavedReport()
        refresh()
    }

    private fun cacheKey(periodType: String) = "reports_summary_$periodType"

    // Last report for the selected period, shown instantly while the fresh one loads.
    private fun showSavedReport() {
        val saved = store?.get(cacheKey(_state.value.selectedPeriodType))?.let { json ->
            runCatching { reportsJson.decodeFromString(ReportsSummaryDto.serializer(), json) }.getOrNull()
        }
        if (saved != null) {
            _state.update { it.copy(reportsSummary = saved, isShowingSavedData = true) }
        }
    }

    fun selectPeriodType(periodType: String) {
        if (_state.value.selectedPeriodType == periodType) return
        _state.update { it.copy(selectedPeriodType = periodType, reportsSummary = null, isShowingSavedData = false) }
        showSavedReport()
        loadReports()
    }

    fun refresh() {
        scope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            runCatching {
                syncEngine.syncAll()
            }
            loadReportsInternal()
        }
    }

    fun loadReports() {
        scope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            loadReportsInternal()
        }
    }

    fun exportTransactionsCsv(onShareFile: (ByteArray, String, String) -> Unit) {
        scope.launch {
            _state.update { it.copy(isExportingCsv = true, error = null) }
            val summary = _state.value.reportsSummary
            val periodType = _state.value.selectedPeriodType
            val startDate = summary?.period?.startDate
            val endDate = summary?.period?.endDate

            runCatching {
                api.exportTransactionsCsv(
                    periodType = periodType,
                    startDate = startDate,
                    endDate = endDate
                )
            }.onSuccess { bytes ->
                _state.update { it.copy(isExportingCsv = false) }
                val filename = if (startDate != null && endDate != null) {
                    val sFormatted = startDate.replace("-", "")
                    val eFormatted = endDate.replace("-", "")
                    "transactions_breakdown_${sFormatted}_to_${eFormatted}.csv"
                } else {
                    "transactions_breakdown.csv"
                }
                onShareFile(bytes, filename, "text/csv")
            }.onFailure { err ->
                _state.update {
                    it.copy(
                        isExportingCsv = false,
                        error = err.message ?: "Error al exportar CSV de transacciones"
                    )
                }
            }
        }
    }

    private suspend fun loadReportsInternal() {
        val periodType = _state.value.selectedPeriodType
        runCatching {
            withTimeout(35_000L) { api.fetchReportsSummary(periodType = periodType) }
        }.onSuccess { dto ->
            runCatching {
                store?.put(cacheKey(dto.period.type), reportsJson.encodeToString(ReportsSummaryDto.serializer(), dto))
            }
            _state.update {
                it.copy(
                    isLoading = false,
                    reportsSummary = dto,
                    selectedPeriodType = dto.period.type,
                    isShowingSavedData = false
                )
            }
        }.onFailure { e ->
            _state.update {
                it.copy(
                    isLoading = false,
                    error = e.describeForUser()
                )
            }
        }
    }
}
