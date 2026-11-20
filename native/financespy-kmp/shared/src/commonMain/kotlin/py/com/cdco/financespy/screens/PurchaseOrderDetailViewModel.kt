package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.PurchaseOrderDto
import py.com.cdco.financespy.sync.OfflineCache
import py.com.cdco.financespy.sync.OfflineCacheKeys
import py.com.cdco.financespy.sync.OfflineStore

class PurchaseOrderDetailViewModel(
    private val purchaseOrderId: String,
    private val api: FinancePyApi,
    store: OfflineStore? = null
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
                    _invoicePhotoBytes.value = null
                }
            }
        } else {
            _invoicePhotoBytes.value = null
        }
    }

    fun uploadInvoicePhoto(fileBytes: ByteArray, fileName: String, contentType: String) {
        viewModelScope.launch {
            _isUploadingPhoto.value = true
            _error.value = null
            try {
                val updated = api.uploadPurchaseOrderInvoicePhoto(purchaseOrderId, fileBytes, fileName, contentType)
                _purchaseOrder.value = updated
                if (contentType.startsWith("image/") || updated.invoice_photo?.content_type?.startsWith("image/") == true) {
                    _invoicePhotoBytes.value = fileBytes
                } else {
                    _invoicePhotoBytes.value = null
                }
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al subir factura"
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
                _invoicePhotoBytes.value = null
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al eliminar factura"
            } finally {
                _isUploadingPhoto.value = false
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
