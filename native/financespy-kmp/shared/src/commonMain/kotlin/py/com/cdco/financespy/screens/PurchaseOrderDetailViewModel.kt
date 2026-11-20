package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.InvoicePhotoDto
import py.com.cdco.financespy.api.dto.PurchaseOrderDto
import py.com.cdco.financespy.sync.OfflineCache
import py.com.cdco.financespy.sync.OfflineCacheKeys
import py.com.cdco.financespy.sync.OfflineOutbox
import py.com.cdco.financespy.sync.OfflineStore

class PurchaseOrderDetailViewModel(
    private val purchaseOrderId: String,
    private val api: FinancePyApi,
    store: OfflineStore? = null,
    private val outbox: OfflineOutbox? = null
) : ViewModel() {

    private val cache = OfflineCache(store)
    private val _purchaseOrder = MutableStateFlow<PurchaseOrderDto?>(
        cache.get(OfflineCacheKeys.purchaseOrderDetail(purchaseOrderId), PurchaseOrderDto.serializer())
            ?: cache.getList(OfflineCacheKeys.PURCHASE_ORDERS_LIST, PurchaseOrderDto.serializer())?.find { it.id == purchaseOrderId }
    )
    val purchaseOrder: StateFlow<PurchaseOrderDto?> = _purchaseOrder.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _isActioning = MutableStateFlow(false)
    val isActioning: StateFlow<Boolean> = _isActioning.asStateFlow()

    private val _invoicePhotoBytes = MutableStateFlow<ByteArray?>(null)
    val invoicePhotoBytes: StateFlow<ByteArray?> = _invoicePhotoBytes.asStateFlow()

    private val _isUploadingPhoto = MutableStateFlow(false)
    val isUploadingPhoto: StateFlow<Boolean> = _isUploadingPhoto.asStateFlow()

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
                val loaded = api.fetchPurchaseOrder(purchaseOrderId)
                _purchaseOrder.value = loaded
                cache.put(OfflineCacheKeys.purchaseOrderDetail(purchaseOrderId), PurchaseOrderDto.serializer(), loaded)
                refreshInvoicePhotoBytes(loaded)
            } catch (e: Exception) {
                if (_purchaseOrder.value == null) {
                    _error.value = e.message ?: "Error al cargar orden de compra"
                }
            } finally {
                _isLoading.value = false
            }
        }
    }

    private fun refreshInvoicePhotoBytes(po: PurchaseOrderDto) {
        val photo = po.invoice_photo
        if ((po.has_invoice_photo || photo != null) && (photo == null || photo.content_type.startsWith("image/"))) {
            viewModelScope.launch {
                try {
                    _invoicePhotoBytes.value = api.downloadPurchaseOrderInvoicePhoto(purchaseOrderId)
                } catch (_: Exception) {
                    // Keep whatever is already on screen (e.g. the photo just taken offline).
                }
            }
        } else {
            _invoicePhotoBytes.value = null
        }
    }

    /** Applies a change locally (screen + cached copies) so the UI reflects it before the server does. */
    private fun applyLocal(transform: (PurchaseOrderDto) -> PurchaseOrderDto) {
        val updated = _purchaseOrder.value?.let(transform) ?: return
        _purchaseOrder.value = updated
        cache.put(OfflineCacheKeys.purchaseOrderDetail(purchaseOrderId), PurchaseOrderDto.serializer(), updated)
        cache.updateList(OfflineCacheKeys.PURCHASE_ORDERS_LIST, PurchaseOrderDto.serializer()) { list ->
            list.map { if (it.id == purchaseOrderId) updated else it }
        }
    }

    fun uploadInvoicePhoto(fileBytes: ByteArray, fileName: String, contentType: String) {
        viewModelScope.launch {
            _isUploadingPhoto.value = true
            _error.value = null
            try {
                val updated = api.uploadPurchaseOrderInvoicePhoto(purchaseOrderId, fileBytes, fileName, contentType)
                _purchaseOrder.value = updated
                cache.put(OfflineCacheKeys.purchaseOrderDetail(purchaseOrderId), PurchaseOrderDto.serializer(), updated)
                if (contentType.startsWith("image/") || updated.invoice_photo?.content_type?.startsWith("image/") == true) {
                    _invoicePhotoBytes.value = fileBytes
                } else {
                    _invoicePhotoBytes.value = null
                }
            } catch (e: Exception) {
                if (outbox != null && outbox.shouldQueue(e)) {
                    outbox.enqueuePurchaseOrderPhoto(
                        purchaseOrderId, fileBytes, fileName, contentType,
                        "Factura de orden #${_purchaseOrder.value?.order_number ?: ""}"
                    )
                    applyLocal {
                        it.copy(
                            has_invoice_photo = true,
                            invoice_photo = InvoicePhotoDto(fileName, contentType, fileBytes.size.toLong(), "")
                        )
                    }
                    _invoicePhotoBytes.value = if (contentType.startsWith("image/")) fileBytes else null
                } else {
                    _error.value = e.message ?: "Error al subir factura"
                }
            } finally {
                _isUploadingPhoto.value = false
            }
        }
    }

    fun deleteInvoicePhoto() {
        viewModelScope.launch {
            _isUploadingPhoto.value = true
            _error.value = null
            try {
                val updated = api.deletePurchaseOrderInvoicePhoto(purchaseOrderId)
                _purchaseOrder.value = updated
                cache.put(OfflineCacheKeys.purchaseOrderDetail(purchaseOrderId), PurchaseOrderDto.serializer(), updated)
                _invoicePhotoBytes.value = null
            } catch (e: Exception) {
                if (outbox != null && outbox.shouldQueue(e)) {
                    outbox.enqueuePurchaseOrderPhotoDelete(purchaseOrderId, "Quitar factura de orden #${_purchaseOrder.value?.order_number ?: ""}")
                    applyLocal { it.copy(has_invoice_photo = false, invoice_photo = null) }
                    _invoicePhotoBytes.value = null
                } else {
                    _error.value = e.message ?: "Error al eliminar factura"
                }
            } finally {
                _isUploadingPhoto.value = false
            }
        }
    }

    fun receivePurchaseOrder() = runStatusAction(
        action = "receive", newStatus = "received", errorMessage = "Error al recibir orden"
    ) { api.receivePurchaseOrder(purchaseOrderId) }

    fun cancelPurchaseOrder() = runStatusAction(
        action = "cancel", newStatus = "cancelled", errorMessage = "Error al cancelar orden"
    ) { api.cancelPurchaseOrder(purchaseOrderId) }

    private fun runStatusAction(
        action: String,
        newStatus: String,
        errorMessage: String,
        call: suspend () -> PurchaseOrderDto
    ) {
        viewModelScope.launch {
            _isActioning.value = true
            _error.value = null
            try {
                val updated = call()
                _purchaseOrder.value = updated
                cache.put(OfflineCacheKeys.purchaseOrderDetail(purchaseOrderId), PurchaseOrderDto.serializer(), updated)
            } catch (e: Exception) {
                if (outbox != null && outbox.shouldQueue(e)) {
                    outbox.enqueuePurchaseOrderAction(action, purchaseOrderId, "Orden #${_purchaseOrder.value?.order_number ?: ""}: $action")
                    applyLocal { it.copy(status = newStatus) }
                } else {
                    _error.value = e.message ?: errorMessage
                }
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
                removeFromCaches()
                onDeleted()
            } catch (e: Exception) {
                if (outbox != null && outbox.shouldQueue(e)) {
                    outbox.enqueuePurchaseOrderAction("delete", purchaseOrderId, "Eliminar orden #${_purchaseOrder.value?.order_number ?: ""}")
                    removeFromCaches()
                    onDeleted()
                } else {
                    _error.value = e.message ?: "Error al eliminar orden"
                }
            } finally {
                _isActioning.value = false
            }
        }
    }

    private fun removeFromCaches() {
        cache.remove(OfflineCacheKeys.purchaseOrderDetail(purchaseOrderId))
        cache.updateList(OfflineCacheKeys.PURCHASE_ORDERS_LIST, PurchaseOrderDto.serializer()) { list ->
            list.filter { it.id != purchaseOrderId }
        }
    }
}
