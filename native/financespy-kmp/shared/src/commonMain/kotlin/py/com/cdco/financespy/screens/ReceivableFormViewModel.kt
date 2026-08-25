package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.CreateReceivableBody
import py.com.cdco.financespy.api.dto.ReceivableDto
import py.com.cdco.financespy.api.dto.UpdateReceivableBody
import py.com.cdco.financespy.db.ReceivableDao
import py.com.cdco.financespy.db.ReceivableEntity

data class ReceivableFormState(
    val name: String = "",
    val totalAmount: String = "",
    val balance: String = "",
    val installmentCount: String = "",
    val dueDay: String = "",
    val currency: String = "PYG",
    val notes: String = "",
    val isEditing: Boolean = false,
    val isSaving: Boolean = false,
    val error: String? = null
)

class ReceivableFormViewModel(
    private val scope: CoroutineScope,
    private val receivableId: String?,
    private val api: FinancePyApi,
    private val receivableDao: ReceivableDao
) {
    private val _state = MutableStateFlow(ReceivableFormState(isEditing = receivableId != null))
    val state: StateFlow<ReceivableFormState> = _state.asStateFlow()

    init {
        if (receivableId != null) {
            scope.launch {
                val entity = receivableDao.getById(receivableId)
                if (entity != null) {
                    _state.update {
                        it.copy(
                            name = entity.name,
                            totalAmount = entity.totalAmount.toString(),
                            balance = entity.balance.toString(),
                            installmentCount = entity.installmentCount?.toString() ?: "",
                            dueDay = entity.dueDay?.toString() ?: "",
                            currency = entity.currency,
                            notes = entity.notes ?: ""
                        )
                    }
                }
            }
        }
    }

    fun updateName(value: String) = _state.update { it.copy(name = value) }
    fun updateTotalAmount(value: String) = _state.update { it.copy(totalAmount = value) }
    fun updateBalance(value: String) = _state.update { it.copy(balance = value) }
    fun updateInstallmentCount(value: String) = _state.update { it.copy(installmentCount = value) }
    fun updateDueDay(value: String) = _state.update { it.copy(dueDay = value) }
    fun updateCurrency(value: String) = _state.update { it.copy(currency = value) }
    fun updateNotes(value: String) = _state.update { it.copy(notes = value) }

    fun save(onSaved: () -> Unit) {
        val current = _state.value
        if (current.isSaving) return

        if (current.name.isBlank()) {
            _state.update { it.copy(error = "El nombre de la cuenta es obligatorio") }
            return
        }

        val parsedTotalAmount = current.totalAmount.toDoubleOrNull()
        if (parsedTotalAmount == null || parsedTotalAmount <= 0) {
            _state.update { it.copy(error = "El monto total debe ser un número mayor a 0") }
            return
        }

        val parsedBalance = if (current.balance.isNotBlank()) {
            current.balance.toDoubleOrNull() ?: run {
                _state.update { it.copy(error = "El saldo debe ser un número válido") }
                return
            }
        } else {
            parsedTotalAmount
        }

        val parsedInstallmentCount = if (current.installmentCount.isNotBlank()) {
            current.installmentCount.toIntOrNull() ?: run {
                _state.update { it.copy(error = "La cantidad de cuotas debe ser un número entero válido") }
                return
            }
        } else {
            null
        }

        val parsedDueDay = if (current.dueDay.isNotBlank()) {
            val day = current.dueDay.toIntOrNull()
            if (day == null || day !in 1..31) {
                _state.update { it.copy(error = "El día de pago debe ser entre 1 y 31") }
                return
            }
            day
        } else {
            null
        }

        _state.update { it.copy(isSaving = true, error = null) }

        scope.launch {
            runCatching {
                if (receivableId != null) {
                    val updateBody = UpdateReceivableBody(
                        name = current.name,
                        total_amount = parsedTotalAmount,
                        balance = parsedBalance,
                        installment_count = parsedInstallmentCount,
                        due_day = parsedDueDay,
                        currency = current.currency,
                        notes = current.notes.ifBlank { null }
                    )
                    val dto = api.updateReceivable(receivableId, updateBody)
                    receivableDao.upsert(dto.toEntity())
                } else {
                    val createBody = CreateReceivableBody(
                        name = current.name,
                        total_amount = parsedTotalAmount,
                        balance = parsedBalance,
                        installment_count = parsedInstallmentCount,
                        due_day = parsedDueDay,
                        currency = current.currency,
                        notes = current.notes.ifBlank { null }
                    )
                    val dto = api.createReceivable(createBody)
                    receivableDao.upsert(dto.toEntity())
                }
            }.onSuccess {
                _state.update { it.copy(isSaving = false) }
                onSaved()
            }.onFailure { error ->
                _state.update { it.copy(isSaving = false, error = error.message ?: "Error al guardar") }
            }
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
