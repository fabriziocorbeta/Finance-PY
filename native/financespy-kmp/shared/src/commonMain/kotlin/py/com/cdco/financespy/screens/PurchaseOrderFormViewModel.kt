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
import py.com.cdco.financespy.api.dto.PurchaseOrderRequestDto
import py.com.cdco.financespy.api.dto.PurchaseOrderPayloadDto
import py.com.cdco.financespy.api.dto.PurchaseOrderItemRequestDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.sync.OfflineCache
import py.com.cdco.financespy.sync.OfflineCacheKeys
import py.com.cdco.financespy.sync.OfflineOutbox
import py.com.cdco.financespy.sync.OfflineStore

data class PurchaseOrderFormItemState(
    val existingId: String? = null,
    val productId: String = "",
    val quantity: Int = 1,
    val unitCost: Double = 0.0
)

class PurchaseOrderFormViewModel(
    private val purchaseOrderId: String?,
    private val api: FinancePyApi,
    private val accountDao: AccountDao,
    store: OfflineStore? = null,
    private val outbox: OfflineOutbox? = null
) : ViewModel() {

    private val cache = OfflineCache(store)
    private val _purchaseOrder = MutableStateFlow<PurchaseOrderDto?>(null)
    val purchaseOrder: StateFlow<PurchaseOrderDto?> = _purchaseOrder.asStateFlow()

    private val _availableProducts = MutableStateFlow(
        cache.getList(OfflineCacheKeys.PRODUCTS_LIST, ProductDto.serializer()) ?: emptyList()
    )
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
                val fresh = api.fetchAllProducts()
                _availableProducts.value = fresh
                cache.putList(OfflineCacheKeys.PRODUCTS_LIST, ProductDto.serializer(), fresh)
            } catch (_: Exception) {
                if (_availableProducts.value.isEmpty()) {
                    _availableProducts.value = cache.getList(OfflineCacheKeys.PRODUCTS_LIST, ProductDto.serializer()) ?: emptyList()
                }
            }
        }
    }

    private fun loadPurchaseOrder(id: String) {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            try {
                val po = api.fetchPurchaseOrder(id)
                _purchaseOrder.value = po
                cache.put(OfflineCacheKeys.purchaseOrderDetail(id), PurchaseOrderDto.serializer(), po)
                val existingPhoto = po.invoice_photo
                if (po.has_invoice_photo || existingPhoto != null) {
                    _pendingPhotoName.value = existingPhoto?.filename ?: "factura_compra"
                    _pendingPhotoContentType.value = existingPhoto?.content_type ?: "image/jpeg"
                    if (existingPhoto == null || existingPhoto.content_type.startsWith("image/")) {
                        viewModelScope.launch {
                            runCatching { api.downloadPurchaseOrderInvoicePhoto(id) }
                                .onSuccess { bytes -> _pendingPhotoBytes.value = bytes }
                        }
                    }
                }
            } catch (e: Exception) {
                val cached = cache.get(OfflineCacheKeys.purchaseOrderDetail(id), PurchaseOrderDto.serializer())
                    ?: cache.getList(OfflineCacheKeys.PURCHASE_ORDERS_LIST, PurchaseOrderDto.serializer())?.find { it.id == id }
                if (cached != null) {
                    _purchaseOrder.value = cached
                } else {
                    _error.value = e.message ?: "Error al cargar orden de compra"
                }
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
        val po = _purchaseOrder.value
        if (po != null && (po.has_invoice_photo || po.invoice_photo != null)) {
            _removeExistingPhoto.value = true
        }
    }

    fun savePurchaseOrder(
        supplierName: String?,
        currency: String,
        expectedDate: String?,
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
                val keptExistingIds = items.mapNotNull { it.existingId }.toSet()
                val destroyedItems = _purchaseOrder.value?.purchase_order_items
                    ?.filter { it.id != null && it.id !in keptExistingIds }
                    ?.map { removed ->
                        PurchaseOrderItemRequestDto(
                            id = removed.id,
                            product_id = removed.product_id,
                            quantity = removed.quantity,
                            unit_cost = removed.unit_cost,
                            _destroy = true
                        )
                    }
                    ?: emptyList()

                val activeItems = items.map { item ->
                    PurchaseOrderItemRequestDto(
                        id = item.existingId,
                        product_id = item.productId,
                        quantity = item.quantity,
                        unit_cost = item.unitCost
                    )
                }

                val payload = PurchaseOrderRequestDto(
                    purchase_order = PurchaseOrderPayloadDto(
                        supplier_name = supplierName.takeIf { !it.isNullOrBlank() },
                        currency = currency.lowercase(),
                        expected_date = expectedDate.takeIf { !it.isNullOrBlank() },
                        notes = notes.takeIf { !it.isNullOrBlank() },
                        account_id = accountId,
                        purchase_order_items_attributes = activeItems + destroyedItems
                    )
                )

                val savedPo = if (purchaseOrderId == null) {
                    api.createPurchaseOrder(payload)
                } else {
                    api.updatePurchaseOrder(purchaseOrderId, payload)
                }
                val photoBytes = _pendingPhotoBytes.value
                if (hasNewLocalPhoto && photoBytes != null) {
                    api.uploadPurchaseOrderInvoicePhoto(
                        poId = savedPo.id,
                        fileBytes = photoBytes,
                        fileName = _pendingPhotoName.value ?: "factura_compra.jpg",
                        contentType = _pendingPhotoContentType.value ?: "image/jpeg"
                    )
                } else if (_removeExistingPhoto.value && purchaseOrderId != null) {
                    api.deletePurchaseOrderInvoicePhoto(savedPo.id)
                }
                onSaved()
            } catch (e: Exception) {
                if (outbox != null && outbox.shouldQueue(e)) {
                    val keptExistingIds = items.mapNotNull { it.existingId }.toSet()
                    val destroyedItems = _purchaseOrder.value?.purchase_order_items
                        ?.filter { it.id != null && it.id !in keptExistingIds }
                        ?.map { removed ->
                            PurchaseOrderItemRequestDto(
                                id = removed.id,
                                product_id = removed.product_id,
                                quantity = removed.quantity,
                                unit_cost = removed.unit_cost,
                                _destroy = true
                            )
                        }
                        ?: emptyList()
                    val activeItems = items.map { item ->
                        PurchaseOrderItemRequestDto(
                            id = item.existingId,
                            product_id = item.productId,
                            quantity = item.quantity,
                            unit_cost = item.unitCost
                        )
                    }
                    val payload = PurchaseOrderRequestDto(
                        purchase_order = PurchaseOrderPayloadDto(
                            supplier_name = supplierName.takeIf { !it.isNullOrBlank() },
                            currency = currency.lowercase(),
                            expected_date = expectedDate.takeIf { !it.isNullOrBlank() },
                            notes = notes.takeIf { !it.isNullOrBlank() },
                            account_id = accountId,
                            purchase_order_items_attributes = activeItems + destroyedItems
                        )
                    )
                    val label = "Orden compra: ${supplierName?.takeIf { it.isNotBlank() } ?: "${items.size} ítems"}"
                    if (purchaseOrderId == null) {
                        outbox.enqueuePurchaseOrder(
                            payload = payload,
                            label = label,
                            photoBytes = if (hasNewLocalPhoto) _pendingPhotoBytes.value else null,
                            photoName = _pendingPhotoName.value,
                            photoContentType = _pendingPhotoContentType.value
                        )
                    } else {
                        outbox.enqueuePurchaseOrderUpdate(
                            id = purchaseOrderId,
                            payload = payload,
                            label = "Actualizar $label",
                            photoBytes = if (hasNewLocalPhoto) _pendingPhotoBytes.value else null,
                            photoName = _pendingPhotoName.value,
                            photoContentType = _pendingPhotoContentType.value,
                            removePhoto = _removeExistingPhoto.value
                        )
                    }
                    onSaved()
                } else {
                    _error.value = e.message ?: "Error al guardar orden"
                }
            } finally {
                _isSaving.value = false
            }
        }
    }
}
