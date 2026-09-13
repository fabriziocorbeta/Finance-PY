package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.ProductDto

class ProductFormViewModel(
    private val productId: String?,
    private val api: FinancePyApi
) : ViewModel() {

    private val _product = MutableStateFlow<ProductDto?>(null)
    val product: StateFlow<ProductDto?> = _product.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isSaving = MutableStateFlow(false)
    val isSaving: StateFlow<Boolean> = _isSaving.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    init {
        if (productId != null) {
            loadProduct(productId)
        }
    }

    private fun loadProduct(id: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            try {
                _product.value = api.fetchProduct(id)
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al cargar producto"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun saveProduct(
        name: String,
        sku: String?,
        category: String?,
        supplier: String?,
        buyPrice: Double,
        sellPrice: Double,
        currency: String,
        minStock: Int,
        initialStock: Int,
        description: String?,
        onSaved: () -> Unit
    ) {
        viewModelScope.launch {
            _isSaving.value = true
            _error.value = null
            try {
                val dto = ProductDto(
                    id = productId ?: "",
                    name = name,
                    sku = sku.takeIf { !it.isNullOrBlank() },
                    category = category.takeIf { !it.isNullOrBlank() },
                    supplier = supplier.takeIf { !it.isNullOrBlank() },
                    buy_price = buyPrice,
                    sell_price = sellPrice,
                    currency = currency.lowercase(),
                    min_stock = minStock,
                    stock = initialStock,
                    description = description.takeIf { !it.isNullOrBlank() }
                )

                if (productId == null) {
                    api.createProduct(dto)
                } else {
                    api.updateProduct(productId, dto)
                }
                onSaved()
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al guardar producto"
            } finally {
                _isSaving.value = false
            }
        }
    }

    fun deleteProduct(onDeleted: () -> Unit) {
        val id = productId ?: return
        viewModelScope.launch {
            _isSaving.value = true
            _error.value = null
            try {
                api.deleteProduct(id)
                onDeleted()
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al eliminar producto"
            } finally {
                _isSaving.value = false
            }
        }
    }
}
