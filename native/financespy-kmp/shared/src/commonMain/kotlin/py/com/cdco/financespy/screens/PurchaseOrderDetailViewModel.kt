package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.PurchaseOrderDto

class PurchaseOrderDetailViewModel(
    private val purchaseOrderId: String,
    private val api: FinancePyApi
) : ViewModel() {

    private val _purchaseOrder = MutableStateFlow<PurchaseOrderDto?>(null)
    val purchaseOrder: StateFlow<PurchaseOrderDto?> = _purchaseOrder.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isActioning = MutableStateFlow(false)
    val isActioning: StateFlow<Boolean> = _isActioning.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    init {
        loadPurchaseOrder()
    }

    fun loadPurchaseOrder() {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            try {
                _purchaseOrder.value = api.fetchPurchaseOrder(purchaseOrderId)
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al cargar orden de compra"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun receivePurchaseOrder() {
        viewModelScope.launch {
            _isActioning.value = true
            _error.value = null
            try {
                _purchaseOrder.value = api.receivePurchaseOrder(purchaseOrderId)
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al recibir orden"
            } finally {
                _isActioning.value = false
            }
        }
    }

    fun cancelPurchaseOrder() {
        viewModelScope.launch {
            _isActioning.value = true
            _error.value = null
            try {
                _purchaseOrder.value = api.cancelPurchaseOrder(purchaseOrderId)
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al cancelar orden"
            } finally {
                _isActioning.value = false
            }
        }
    }

    fun deletePurchaseOrder(onDeleted: () -> Unit) {
        viewModelScope.launch {
            _isActioning.value = true
            _error.value = null
            try {
                api.deletePurchaseOrder(purchaseOrderId)
                onDeleted()
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al eliminar orden"
            } finally {
                _isActioning.value = false
            }
        }
    }
}
