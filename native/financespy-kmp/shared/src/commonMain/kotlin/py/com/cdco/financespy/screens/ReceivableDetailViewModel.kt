package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.db.ReceivableDao
import py.com.cdco.financespy.db.ReceivableEntity

data class ReceivableDetailState(
    val receivable: ReceivableEntity? = null,
    val isDeleting: Boolean = false,
    val deleteError: String? = null
)

class ReceivableDetailViewModel(
    private val scope: CoroutineScope,
    private val receivableId: String,
    private val api: FinancePyApi,
    private val receivableDao: ReceivableDao
) {
    private val _state = MutableStateFlow(ReceivableDetailState())
    val state: StateFlow<ReceivableDetailState> = _state.asStateFlow()

    init {
        scope.launch {
            receivableDao.observeById(receivableId).collect { receivable ->
                _state.update { it.copy(receivable = receivable) }
            }
        }
    }

    fun delete(onDeleted: () -> Unit) {
        if (_state.value.isDeleting) return
        _state.update { it.copy(isDeleting = true, deleteError = null) }
        scope.launch {
            runCatching {
                api.deleteReceivable(receivableId)
                receivableDao.deleteById(receivableId)
            }.onSuccess {
                _state.update { it.copy(isDeleting = false) }
                onDeleted()
            }.onFailure { error ->
                _state.update { it.copy(isDeleting = false, deleteError = error.message ?: "Error al borrar") }
            }
        }
    }
}
