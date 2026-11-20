package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.InvoicePhotoDto
import py.com.cdco.financespy.api.dto.SaleDto
import py.com.cdco.financespy.sync.OfflineCache
import py.com.cdco.financespy.sync.OfflineCacheKeys
import py.com.cdco.financespy.sync.OfflineOutbox
import py.com.cdco.financespy.sync.OfflineStore

class SaleDetailViewModel(
    private val saleId: String,
    private val api: FinancePyApi,
    store: OfflineStore? = null,
    private val outbox: OfflineOutbox? = null
) : ViewModel() {

    private val cache = OfflineCache(store)
    private val _sale = MutableStateFlow<SaleDto?>(
        cache.get(OfflineCacheKeys.saleDetail(saleId), SaleDto.serializer())
            ?: cache.getList(OfflineCacheKeys.SALES_LIST, SaleDto.serializer())?.find { it.id == saleId }
    )
    val sale: StateFlow<SaleDto?> = _sale.asStateFlow()

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
        loadSale()
    }

    fun loadSale() {
        viewModelScope.launch {
            _isLoading.value = true
            _error.value = null
            try {
                val loaded = api.fetchSale(saleId)
                _sale.value = loaded
                cache.put(OfflineCacheKeys.saleDetail(saleId), SaleDto.serializer(), loaded)
                refreshInvoicePhotoBytes(loaded)
            } catch (e: Exception) {
                if (_sale.value == null) {
                    _error.value = e.message ?: "Error al cargar venta"
                }
            } finally {
                _isLoading.value = false
            }
        }
    }

    private fun refreshInvoicePhotoBytes(sale: SaleDto) {
        val photo = sale.invoice_photo
        if ((sale.has_invoice_photo || photo != null) && (photo == null || photo.content_type.startsWith("image/"))) {
            viewModelScope.launch {
                try {
                    _invoicePhotoBytes.value = api.downloadSaleInvoicePhoto(saleId)
                } catch (_: Exception) {
                    // Keep whatever is already on screen (e.g. the photo just taken offline).
                }
            }
        } else {
            _invoicePhotoBytes.value = null
        }
    }

    /** Applies a change locally (screen + cached copies) so the UI reflects it before the server does. */
    private fun applyLocal(transform: (SaleDto) -> SaleDto) {
        val updated = _sale.value?.let(transform) ?: return
        _sale.value = updated
        cache.put(OfflineCacheKeys.saleDetail(saleId), SaleDto.serializer(), updated)
        cache.updateList(OfflineCacheKeys.SALES_LIST, SaleDto.serializer()) { list ->
            list.map { if (it.id == saleId) updated else it }
        }
    }

    fun uploadInvoicePhoto(fileBytes: ByteArray, fileName: String, contentType: String) {
        viewModelScope.launch {
            _isUploadingPhoto.value = true
            _error.value = null
            try {
                val updated = api.uploadSaleInvoicePhoto(saleId, fileBytes, fileName, contentType)
                _sale.value = updated
                cache.put(OfflineCacheKeys.saleDetail(saleId), SaleDto.serializer(), updated)
                if (contentType.startsWith("image/") || updated.invoice_photo?.content_type?.startsWith("image/") == true) {
                    _invoicePhotoBytes.value = fileBytes
                } else {
                    _invoicePhotoBytes.value = null
                }
            } catch (e: Exception) {
                if (outbox != null && outbox.shouldQueue(e)) {
                    outbox.enqueueSalePhoto(saleId, fileBytes, fileName, contentType, "Factura de venta #${_sale.value?.sale_number ?: ""}")
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
                val updated = api.deleteSaleInvoicePhoto(saleId)
                _sale.value = updated
                cache.put(OfflineCacheKeys.saleDetail(saleId), SaleDto.serializer(), updated)
                _invoicePhotoBytes.value = null
            } catch (e: Exception) {
                if (outbox != null && outbox.shouldQueue(e)) {
                    outbox.enqueueSalePhotoDelete(saleId, "Quitar factura de venta #${_sale.value?.sale_number ?: ""}")
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

    fun completeSale() = runStatusAction(
        action = "complete", newStatus = "completed", errorMessage = "Error al completar venta"
    ) { api.completeSale(saleId) }

    fun cancelSale() = runStatusAction(
        action = "cancel", newStatus = "cancelled", errorMessage = "Error al cancelar venta"
    ) { api.cancelSale(saleId) }

    private fun runStatusAction(
        action: String,
        newStatus: String,
        errorMessage: String,
        call: suspend () -> SaleDto
    ) {
        viewModelScope.launch {
            _isActioning.value = true
            _error.value = null
            try {
                val updated = call()
                _sale.value = updated
                cache.put(OfflineCacheKeys.saleDetail(saleId), SaleDto.serializer(), updated)
            } catch (e: Exception) {
                if (outbox != null && outbox.shouldQueue(e)) {
                    outbox.enqueueSaleAction(action, saleId, "Venta #${_sale.value?.sale_number ?: ""}: $action")
                    applyLocal { it.copy(status = newStatus) }
                } else {
                    _error.value = e.message ?: errorMessage
                }
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
                removeFromCaches()
                onDeleted()
            } catch (e: Exception) {
                if (outbox != null && outbox.shouldQueue(e)) {
                    outbox.enqueueSaleAction("delete", saleId, "Eliminar venta #${_sale.value?.sale_number ?: ""}")
                    removeFromCaches()
                    onDeleted()
                } else {
                    _error.value = e.message ?: "Error al eliminar venta"
                }
            } finally {
                _isActioning.value = false
            }
        }
    }

    private fun removeFromCaches() {
        cache.remove(OfflineCacheKeys.saleDetail(saleId))
        cache.updateList(OfflineCacheKeys.SALES_LIST, SaleDto.serializer()) { list -> list.filter { it.id != saleId } }
    }
}
