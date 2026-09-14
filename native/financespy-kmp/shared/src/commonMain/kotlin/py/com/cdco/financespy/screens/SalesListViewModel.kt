package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.SaleDto

class SalesListViewModel(
    private val api: FinancePyApi
) : ViewModel() {

    private val _sales = MutableStateFlow<List<SaleDto>>(emptyList())
    val sales: StateFlow<List<SaleDto>> = _sales.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    fun refresh() {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            try {
                _sales.value = api.fetchAllSales()
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al cargar ventas"
            } finally {
                _isLoading.value = false
            }
        }
    }
}
