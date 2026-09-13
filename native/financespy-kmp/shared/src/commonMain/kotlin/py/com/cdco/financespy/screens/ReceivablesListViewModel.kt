package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.ReceivableDto
import py.com.cdco.financespy.db.ReceivableDao
import py.com.cdco.financespy.db.ReceivableEntity

class ReceivablesListViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    private val receivableDao: ReceivableDao
) {
    val receivables: StateFlow<List<ReceivableEntity>> = receivableDao.observeAll()
        .stateIn(
            scope = scope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = emptyList()
        )

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    fun refresh() {
        scope.launch {
            _isLoading.value = true
            _error.value = null
            runCatching {
                val remote = api.fetchAllReceivables()
                val entities = remote.map { it.toEntity() }
                receivableDao.upsertAll(entities)
                receivableDao.deleteAllExcept(entities.map { it.id })
            }.onFailure { throwable ->
                _error.value = throwable.message ?: "Error al cargar las cuentas a cobrar"
            }
            _isLoading.value = false
        }
    }
}

private fun ReceivableDto.toEntity() = ReceivableEntity(
    id = id,
    name = name ?: "(sin nombre)",
    totalAmount = total_amount ?: 0.0,
    balance = balance ?: 0.0,
    balanceCents = balance_cents ?: 0L,
    originalBalance = original_balance ?: 0.0,
    originalBalanceCents = original_balance_cents ?: 0L,
    paidAmount = paid_amount ?: 0.0,
    paidAmountCents = paid_amount_cents ?: 0L,
    percentPaid = percent_paid ?: 0.0,
    installmentCount = installment_count,
    dueDay = due_day,
    currency = currency ?: "PYG",
    notes = notes,
    updatedAt = updated_at ?: ""
)
