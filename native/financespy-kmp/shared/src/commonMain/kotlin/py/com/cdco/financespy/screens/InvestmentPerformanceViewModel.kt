package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.InvestmentSummaryDto

data class InvestmentPerformanceState(
    val isLoading: Boolean = false,
    val error: String? = null,
    val investmentSummary: InvestmentSummaryDto? = null
)

class InvestmentPerformanceViewModel(
    private val api: FinancePyApi
) : ViewModel() {

    private val _state = MutableStateFlow(InvestmentPerformanceState())
    val state: StateFlow<InvestmentPerformanceState> = _state.asStateFlow()

    fun refresh() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                val dashboard = api.fetchDashboard()
                _state.update {
                    it.copy(isLoading = false, investmentSummary = dashboard.investment_summary)
                }
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, error = e.message ?: "Error al cargar el rendimiento de inversiones") }
            }
        }
    }
}
