package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.SaleDto

class SaleDetailViewModel(
    private val saleId: String,
    private val api: FinancePyApi
) : ViewModel() {

    private val _sale = MutableStateFlow<SaleDto?>(null)
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
                refreshInvoicePhotoBytes(loaded)
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al cargar venta"
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
                val updated = api.uploadSaleInvoicePhoto(saleId, fileBytes, fileName, contentType)
                _sale.value = updated
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
                val updated = api.deleteSaleInvoicePhoto(saleId)
                _sale.value = updated
                _invoicePhotoBytes.value = null
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al eliminar factura"
            } finally {
                _isUploadingPhoto.value = false
            }
        }
    }

    fun completeSale() {
        viewModelScope.launch {
            _isActioning.value = true
            _error.value = null
            try {
                _sale.value = api.completeSale(saleId)
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al completar venta"
            } finally {
                _isActioning.value = false
            }
        }
    }

    fun cancelSale() {
        viewModelScope.launch {
            _isActioning.value = true
            _error.value = null
            try {
                _sale.value = api.cancelSale(saleId)
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al cancelar venta"
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
                onDeleted()
            } catch (e: Exception) {
                _error.value = e.message ?: "Error al eliminar venta"
            } finally {
                _isActioning.value = false
            }
        }
    }
}
