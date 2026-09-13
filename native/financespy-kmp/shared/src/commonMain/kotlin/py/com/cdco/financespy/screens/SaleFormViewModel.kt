package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.ProductDto
import py.com.cdco.financespy.api.dto.SaleDto

data class SaleFormItemState(
    val productId: String = "",
    val quantity: Int = 1,
    val unitPrice: Double = 0.0
)

class SaleFormViewModel(
    private val saleId: String?,
    private val api: FinancePyApi
) : ViewModel() {

    private val _sale = MutableStateFlow<SaleDto?>(null)
    val sale: StateFlow<SaleDto?> = _sale.asStateFlow()

    private val _availableProducts = MutableStateFlow<List<ProductDto>>(emptyList())
    val availableProducts: StateFlow<List<ProductDto>> = _availableProducts.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isSaving = MutableStateFlow(false)
    val isSaving: StateFlow<Boolean> = _isSaving.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    init {
        loadProducts()
        if (saleId != null) {
            loadSale(saleId)
        }
    }

    private fun loadProducts() {
        viewModelScope.launch {
            try {
                _availableProducts.value = api.fetchAllProducts()
            } catch (e: Exception) {
                // handle silently or expose
            }
        }
    }

    private fun loadSale(id: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            try {
                _sale.value = api.fetchSale(id)
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al cargar venta"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun saveSale(
        clientName: String?,
        currency: String,
        notes: String?,
        items: List<SaleFormItemState>,
        onSaved: () -> Unit
    ) {
        viewModelScope.launch {
            _isSaving.value = true
            _error.value = null
            try {
                val itemsAttributes = items.map { item ->
                    mapOf(
                        "product_id" to item.productId,
                        "quantity" to item.quantity,
                        "unit_price" to item.unitPrice
                    )
                }

                val payload = mapOf(
                    "client_name" to clientName.takeIf { !it.isNullOrBlank() },
                    "currency" to currency.lowercase(),
                    "notes" to notes.takeIf { !it.isNullOrBlank() },
                    "sale_items_attributes" to itemsAttributes
                )

                if (saleId == null) {
                    api.createSale(payload)
                } else {
                    api.updateSale(saleId, payload)
                }
                onSaved()
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al guardar venta"
            } finally {
                _isSaving.value = false
            }
        }
    }
}
