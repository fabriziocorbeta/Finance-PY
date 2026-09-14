package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.SaleDto

class SaleDetailViewModel(
    private val saleId: String,
    private val api: FinancePyApi
) : ViewModel() {

    private val _sale = MutableStateFlow<SaleDto?>(null)
    val sale: StateFlow<SaleDto?> = _sale.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isActioning = MutableStateFlow(false)
    val isActioning: StateFlow<Boolean> = _isActioning.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    init {
        loadSale()
    }

    fun loadSale() {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            try {
                _sale.value = api.fetchSale(saleId)
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al cargar venta"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun completeSale() {
        viewModelScope.launch {
            _isActioning.value = true
            _error.value = null
            try {
                _sale.value = api.completeSale(saleId)
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al completar venta"
            } finally {
                _isActioning.value = false
            }
        }
    }

    fun cancelSale() {
        viewModelScope.launch {
            _isActioning.value = true
            _error.value = null
            try {
                _sale.value = api.cancelSale(saleId)
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al cancelar venta"
            } finally {
                _isActioning.value = false
            }
        }
    }

    fun deleteSale(onDeleted: () -> Unit) {
        viewModelScope.launch {
            _isActioning.value = true
            _error.value = null
            try {
                api.deleteSale(saleId)
                onDeleted()
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al eliminar venta"
            } finally {
                _isActioning.value = false
            }
        }
    }
}
