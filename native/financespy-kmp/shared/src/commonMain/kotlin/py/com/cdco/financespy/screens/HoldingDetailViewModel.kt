package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi

data class PricePoint(val date: String, val price: Double)

enum class PriceRange(val label: String, val points: Int) {
    ONE_MONTH("1M", 22),
    THREE_MONTHS("3M", 65),
    SIX_MONTHS("6M", 130),
    ONE_YEAR("1A", 260),
    ALL("Todo", Int.MAX_VALUE)
}

data class HoldingDetailState(
    val isLoading: Boolean = false,
    val error: String? = null,
    val ticker: String = "",
    val name: String = "",
    val currency: String = "USD",
    val fullHistory: List<PricePoint> = emptyList(),
    val selectedRange: PriceRange = PriceRange.THREE_MONTHS
) {
    val visibleHistory: List<PricePoint>
        get() = if (selectedRange == PriceRange.ALL) fullHistory else fullHistory.takeLast(selectedRange.points)

    val currentPrice: Double?
        get() = fullHistory.lastOrNull()?.price

    val periodChangePct: Double?
        get() {
            val visible = visibleHistory
            val first = visible.firstOrNull()?.price ?: return null
            val last = visible.lastOrNull()?.price ?: return null
            if (first == 0.0) return null
            return (last - first) / first * 100.0
        }

    val periodHigh: Double?
        get() = visibleHistory.maxOfOrNull { it.price }

    val periodLow: Double?
        get() = visibleHistory.minOfOrNull { it.price }
}

class HoldingDetailViewModel(
    private val api: FinancePyApi,
    private val securityId: String
) : ViewModel() {

    private val _state = MutableStateFlow(HoldingDetailState())
    val state: StateFlow<HoldingDetailState> = _state.asStateFlow()

    fun selectRange(range: PriceRange) {
        _state.update { it.copy(selectedRange = range) }
    }

    fun refresh() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                val dtos = api.fetchAllSecurityPrices(securityId).sortedBy { it.date }
                val prices = dtos.mapNotNull { dto -> dto.price_amount.toDoubleOrNull()?.let { PricePoint(dto.date, it) } }
                val lastDto = dtos.lastOrNull()
                _state.update {
                    it.copy(
                        isLoading = false,
                        fullHistory = prices,
                        ticker = lastDto?.security?.ticker ?: it.ticker,
                        name = lastDto?.security?.name ?: lastDto?.security?.ticker ?: it.name,
                        currency = lastDto?.currency ?: it.currency
                    )
                }
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, error = e.message ?: "Error al cargar el historial de precios") }
            }
        }
    }
}
