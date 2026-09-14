package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.ProductDto
import py.com.cdco.financespy.api.dto.PurchaseOrderDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity

data class PurchaseOrderFormItemState(
    val productId: String = "",
    val quantity: Int = 1,
    val unitCost: Double = 0.0
)

class PurchaseOrderFormViewModel(
    private val purchaseOrderId: String?,
    private val api: FinancePyApi,
    private val accountDao: AccountDao
) : ViewModel() {

    private val _purchaseOrder = MutableStateFlow<PurchaseOrderDto?>(null)
    val purchaseOrder: StateFlow<PurchaseOrderDto?> = _purchaseOrder.asStateFlow()

    private val _availableProducts = MutableStateFlow<List<ProductDto>>(emptyList())
    val availableProducts: StateFlow<List<ProductDto>> = _availableProducts.asStateFlow()

    private val _availableAccounts = MutableStateFlow<List<AccountEntity>>(emptyList())
    val availableAccounts: StateFlow<List<AccountEntity>> = _availableAccounts.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isSaving = MutableStateFlow(false)
    val isSaving: StateFlow<Boolean> = _isSaving.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    init {
        loadProducts()
        loadAccounts()
        if (purchaseOrderId != null) {
            loadPurchaseOrder(purchaseOrderId)
        }
    }

    private fun loadAccounts() {
        viewModelScope.launch {
            accountDao.observeAll().collect { accounts ->
                _availableAccounts.value = accounts
            }
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

    private fun loadPurchaseOrder(id: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            try {
                _purchaseOrder.value = api.fetchPurchaseOrder(id)
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al cargar orden de compra"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun savePurchaseOrder(
        supplierName: String?,
        currency: String,
        notes: String?,
        accountId: String,
        items: List<PurchaseOrderFormItemState>,
        onSaved: () -> Unit
    ) {
        if (accountId.isBlank()) {
            _error.value = "Seleccioná una cuenta"
            return
        }

        viewModelScope.launch {
            _isSaving.value = true
            _error.value = null
            try {
                val itemsAttributes = items.map { item ->
                    mapOf(
                        "product_id" to item.productId,
                        "quantity" to item.quantity,
                        "unit_cost" to item.unitCost
                    )
                }

                val payload = mapOf(
                    "supplier_name" to supplierName.takeIf { !it.isNullOrBlank() },
                    "currency" to currency.lowercase(),
                    "notes" to notes.takeIf { !it.isNullOrBlank() },
                    "account_id" to accountId,
                    "purchase_order_items_attributes" to itemsAttributes
                )

                if (purchaseOrderId == null) {
                    api.createPurchaseOrder(payload)
                } else {
                    api.updatePurchaseOrder(purchaseOrderId, payload)
                }
                onSaved()
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al guardar orden"
            } finally {
                _isSaving.value = false
            }
        }
    }
}
