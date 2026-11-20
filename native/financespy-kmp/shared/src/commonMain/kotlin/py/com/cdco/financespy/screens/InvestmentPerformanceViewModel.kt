package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.DashboardDto
import py.com.cdco.financespy.api.dto.InvestmentSummaryDto
import py.com.cdco.financespy.sync.OfflineCache
import py.com.cdco.financespy.sync.OfflineCacheKeys
import py.com.cdco.financespy.sync.OfflineStore

data class InvestmentPerformanceState(
    val isLoading: Boolean = false,
    val error: String? = null,
    val investmentSummary: InvestmentSummaryDto? = null
)

class InvestmentPerformanceViewModel(
    private val api: FinancePyApi,
    store: OfflineStore? = null
) : ViewModel() {

    private val cache = OfflineCache(store)
    private val _state = MutableStateFlow(
        InvestmentPerformanceState(
            investmentSummary = cache.get(OfflineCacheKeys.DASHBOARD_DTO, DashboardDto.serializer())?.investment_summary
        )
    )
    val state: StateFlow<InvestmentPerformanceState> = _state.asStateFlow()

    fun refresh() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                val dashboard = api.fetchDashboard()
                cache.put(OfflineCacheKeys.DASHBOARD_DTO, DashboardDto.serializer(), dashboard)
                _state.update {
                    it.copy(isLoading = false, investmentSummary = dashboard.investment_summary)
                }
            } catch (e: Exception) {
                val cached = cache.get(OfflineCacheKeys.DASHBOARD_DTO, DashboardDto.serializer())?.investment_summary
                _state.update {
                    it.copy(
                        isLoading = false,
                        investmentSummary = it.investmentSummary ?: cached,
                        error = if (it.investmentSummary == null && cached == null) (e.message ?: "Error al cargar el rendimiento de inversiones") else null
                    )
                }
            }
        }
    }
}
