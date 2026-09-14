package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.ReportsSummaryDto
import py.com.cdco.financespy.sync.SyncEngine

data class ReportsState(
    val reportsSummary: ReportsSummaryDto? = null,
    val selectedPeriodType: String = "monthly",
    val isLoading: Boolean = false,
    val isExportingCsv: Boolean = false,
    val error: String? = null
)

class ReportsViewModel(
    private val scope: CoroutineScope,
    private val syncEngine: SyncEngine,
    private val api: FinancePyApi
) {
    private val _state = MutableStateFlow(ReportsState())
    val state: StateFlow<ReportsState> = _state.asStateFlow()

    init {
        refresh()
    }

    fun selectPeriodType(periodType: String) {
        if (_state.value.selectedPeriodType == periodType) return
        _state.update { it.copy(selectedPeriodType = periodType) }
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
            api.fetchReportsSummary(periodType = periodType)
        }.onSuccess { dto ->
            _state.update {
                it.copy(
                    isLoading = false,
                    reportsSummary = dto,
                    selectedPeriodType = dto.period.type
                )
            }
        }.onFailure { e ->
            _state.update {
                it.copy(
                    isLoading = false,
                    error = e.message ?: "Error al cargar reportes"
                )
            }
        }
    }
}
