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
import py.com.cdco.financespy.api.dto.SaleRequestDto
import py.com.cdco.financespy.api.dto.SalePayloadDto
import py.com.cdco.financespy.api.dto.SaleItemRequestDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity

data class SaleFormItemState(
    val productId: String = "",
    val quantity: Int = 1,
    val unitPrice: Double = 0.0
)

class SaleFormViewModel(
    private val saleId: String?,
    private val api: FinancePyApi,
    private val accountDao: AccountDao
) : ViewModel() {

    private val _sale = MutableStateFlow<SaleDto?>(null)
    val sale: StateFlow<SaleDto?> = _sale.asStateFlow()

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

    private val _pendingPhotoBytes = MutableStateFlow<ByteArray?>(null)
    val pendingPhotoBytes: StateFlow<ByteArray?> = _pendingPhotoBytes.asStateFlow()

    private val _pendingPhotoName = MutableStateFlow<String?>(null)
    val pendingPhotoName: StateFlow<String?> = _pendingPhotoName.asStateFlow()

    private val _pendingPhotoContentType = MutableStateFlow<String?>(null)
    val pendingPhotoContentType: StateFlow<String?> = _pendingPhotoContentType.asStateFlow()

    private val _removeExistingPhoto = MutableStateFlow(false)
    val removeExistingPhoto: StateFlow<Boolean> = _removeExistingPhoto.asStateFlow()

    private var hasNewLocalPhoto = false

    init {
        loadProducts()
        loadAccounts()
        if (saleId != null) {
            loadSale(saleId)
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

    private fun loadSale(id: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            try {
                val loadedSale = api.fetchSale(id)
                _sale.value = loadedSale
                val existingPhoto = loadedSale.invoice_photo
                if (loadedSale.has_invoice_photo || existingPhoto != null) {
                    _pendingPhotoName.value = existingPhoto?.filename ?: "factura_venta"
                    _pendingPhotoContentType.value = existingPhoto?.content_type ?: "image/jpeg"
                    if (existingPhoto == null || existingPhoto.content_type.startsWith("image/")) {
                        viewModelScope.launch {
                            runCatching { api.downloadSaleInvoicePhoto(id) }
                                .onSuccess { bytes -> _pendingPhotoBytes.value = bytes }
                        }
                    }
                }
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al cargar venta"
            } finally {
                _isLoading.value = false
            }
        }
    }

    fun onPhotoSelected(bytes: ByteArray, fileName: String, contentType: String) {
        _pendingPhotoBytes.value = bytes
        _pendingPhotoName.value = fileName
        _pendingPhotoContentType.value = contentType
        hasNewLocalPhoto = true
        _removeExistingPhoto.value = false
    }

    fun onRemovePhoto() {
        _pendingPhotoBytes.value = null
        _pendingPhotoName.value = null
        _pendingPhotoContentType.value = null
        hasNewLocalPhoto = false
        val currentSale = _sale.value
        if (currentSale != null && (currentSale.has_invoice_photo || currentSale.invoice_photo != null)) {
            _removeExistingPhoto.value = true
        }
    }

    fun saveSale(
        clientName: String?,
        currency: String,
        notes: String?,
        accountId: String,
        items: List<SaleFormItemState>,
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
                    SaleItemRequestDto(
                        product_id = item.productId,
                        quantity = item.quantity,
                        unit_price = item.unitPrice
                    )
                }

                val payload = SaleRequestDto(
                    sale = SalePayloadDto(
                        client_name = clientName.takeIf { !it.isNullOrBlank() },
                        currency = currency.lowercase(),
                        notes = notes.takeIf { !it.isNullOrBlank() },
                        account_id = accountId,
                        sale_items_attributes = itemsAttributes
                    )
                )

                val savedSale = if (saleId == null) {
                    api.createSale(payload)
                } else {
                    api.updateSale(saleId, payload)
                }
                val photoBytes = _pendingPhotoBytes.value
                if (hasNewLocalPhoto && photoBytes != null) {
                    api.uploadSaleInvoicePhoto(
                        saleId = savedSale.id,
                        fileBytes = photoBytes,
                        fileName = _pendingPhotoName.value ?: "factura_venta.jpg",
                        contentType = _pendingPhotoContentType.value ?: "image/jpeg"
                    )
                } else if (_removeExistingPhoto.value && saleId != null) {
                    api.deleteSaleInvoicePhoto(savedSale.id)
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
