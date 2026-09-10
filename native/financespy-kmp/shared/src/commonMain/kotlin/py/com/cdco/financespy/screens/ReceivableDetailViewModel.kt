package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.CreateTransferBody
import py.com.cdco.financespy.db.ReceivableDao
import py.com.cdco.financespy.db.ReceivableEntity
import py.com.cdco.financespy.sync.currentIsoDate

data class ReceivableDetailState(
    val receivable: ReceivableEntity? = null,
    val isDeleting: Boolean = false,
    val deleteError: String? = null,
    val showPaymentDialog: Boolean = false,
    val paymentAccounts: List<AccountDto> = emptyList(),
    val receivableAccountId: String? = null,
    val paymentFromAccountId: String? = null,
    val paymentAmount: String = "",
    val paymentDate: String = currentIsoDate(),
    val isRegisteringPayment: Boolean = false,
    val paymentError: String? = null
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

    fun openPaymentDialog() {
        _state.update { it.copy(showPaymentDialog = true, paymentError = null) }
        scope.launch {
            runCatching {
                val receivable = api.fetchReceivable(receivableId)
                val accounts = api.fetchAllAccounts().filter { it.account_type == "Depository" && it.status == "active" }
                Pair(receivable.account_id, accounts)
            }.onSuccess { (accountId, accounts) ->
                _state.update {
                    it.copy(
                        receivableAccountId = accountId,
                        paymentAccounts = accounts,
                        paymentFromAccountId = it.paymentFromAccountId ?: accounts.firstOrNull()?.id
                    )
                }
            }.onFailure { error ->
                _state.update { it.copy(paymentError = error.message ?: "No se pudieron cargar las cuentas") }
            }
        }
    }

    fun closePaymentDialog() {
        _state.update { it.copy(showPaymentDialog = false, paymentError = null) }
    }

    fun updatePaymentFromAccountId(accountId: String) {
        _state.update { it.copy(paymentFromAccountId = accountId) }
    }

    fun updatePaymentAmount(amount: String) {
        _state.update { it.copy(paymentAmount = amount) }
    }

    fun updatePaymentDate(date: String) {
        _state.update { it.copy(paymentDate = date) }
    }

    fun registerPayment(onDone: () -> Unit) {
        val current = _state.value
        val fromAccountId = current.paymentFromAccountId
        val toAccountId = current.receivableAccountId
        val amount = current.paymentAmount.toDoubleOrNull()

        if (fromAccountId == null || toAccountId == null || amount == null || amount <= 0.0) {
            _state.update { it.copy(paymentError = "Completá cuenta e importe válido") }
            return
        }

        _state.update { it.copy(isRegisteringPayment = true, paymentError = null) }
        scope.launch {
            runCatching {
                api.createTransfer(
                    CreateTransferBody(
                        from_account_id = fromAccountId,
                        to_account_id = toAccountId,
                        amount = amount,
                        date = current.paymentDate
                    )
                )
            }.onSuccess {
                _state.update { it.copy(isRegisteringPayment = false, showPaymentDialog = false, paymentAmount = "") }
                onDone()
            }.onFailure { error ->
                _state.update { it.copy(isRegisteringPayment = false, paymentError = error.message ?: "No se pudo registrar el pago") }
            }
        }
    }
}
