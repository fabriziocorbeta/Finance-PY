package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.db.ReceivableDao
import py.com.cdco.financespy.db.ReceivableEntity

data class ReceivablesListState(
    val isLoading: Boolean = false,
    val error: String? = null
)

class ReceivablesListViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    private val receivableDao: ReceivableDao
) {
    private val _state = MutableStateFlow(ReceivablesListState())
    val state: StateFlow<ReceivablesListState> = _state.asStateFlow()

    val receivables: StateFlow<List<ReceivableEntity>> = receivableDao.observeAll()
        .stateIn(
            scope = scope,
            started = SharingStarted.Eagerly,
            initialValue = emptyList()
        )

    fun refresh() {
        scope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            runCatching {
                val remote = api.fetchAllReceivables()
                val entities = remote.map { remoteRec ->
                    ReceivableEntity(
                        id = remoteRec.id,
                        name = remoteRec.name ?: "(sin nombre)",
                        totalAmount = remoteRec.total_amount ?: 0.0,
                        balance = remoteRec.balance ?: 0.0,
                        balanceCents = remoteRec.balance_cents ?: 0L,
                        originalBalance = remoteRec.original_balance ?: 0.0,
                        originalBalanceCents = remoteRec.original_balance_cents ?: 0L,
                        paidAmount = remoteRec.paid_amount ?: 0.0,
                        paidAmountCents = remoteRec.paid_amount_cents ?: 0L,
                        percentPaid = remoteRec.percent_paid ?: 0.0,
                        installmentCount = remoteRec.installment_count,
                        dueDay = remoteRec.due_day,
                        currency = remoteRec.currency ?: "PYG",
                        notes = remoteRec.notes,
                        updatedAt = remoteRec.updated_at ?: ""
                    )
                }
                receivableDao.upsertAll(entities)
                receivableDao.deleteAllExcept(entities.map { it.id })
            }.onSuccess {
                _state.update { it.copy(isLoading = false, error = null) }
            }.onFailure { e ->
                _state.update { it.copy(isLoading = false, error = e.message ?: "Error al cargar las cuentas a cobrar") }
            }
        }
    }
}
