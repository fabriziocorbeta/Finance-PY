package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.SaleDto
import py.com.cdco.financespy.sync.OfflineCache
import py.com.cdco.financespy.sync.OfflineCacheKeys
import py.com.cdco.financespy.sync.OfflineStore

class SalesListViewModel(
    private val api: FinancePyApi,
    store: OfflineStore? = null
) : ViewModel() {

    private val cache = OfflineCache(store)
    private val _sales = MutableStateFlow(
        cache.getList(OfflineCacheKeys.SALES_LIST, SaleDto.serializer()) ?: emptyList()
    )
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
                val fresh = api.fetchAllSales()
                _sales.value = fresh
                cache.putList(OfflineCacheKeys.SALES_LIST, SaleDto.serializer(), fresh)
            } catch (e: Exception) {
                if (_sales.value.isEmpty()) {
                    _error.value = e.message ?: "Error al cargar ventas"
                }
            } finally {
                _isLoading.value = false
            }
        }
    }
}
