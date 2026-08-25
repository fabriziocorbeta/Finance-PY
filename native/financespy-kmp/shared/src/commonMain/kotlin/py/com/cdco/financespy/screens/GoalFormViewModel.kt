package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.CreateGoalBody
import py.com.cdco.financespy.api.dto.UpdateGoalBody
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.db.GoalDao
import py.com.cdco.financespy.db.GoalEntity

data class GoalFormState(
    val isEditing: Boolean = false,
    val name: String = "",
    val targetAmount: String = "",
    val currency: String = "USD",
    val targetDate: String = "",
    val color: String = "",
    val icon: String = "",
    val notes: String = "",
    val selectedAccountIds: Set<String> = emptySet(),
    val availableAccounts: List<AccountEntity> = emptyList(),
    val isSaving: Boolean = false,
    val error: String? = null
)

class GoalFormViewModel(
    private val scope: CoroutineScope,
    private val goalId: String?,
    private val api: FinancePyApi,
    private val goalDao: GoalDao,
    private val accountDao: AccountDao
) {
    private val _state = MutableStateFlow(GoalFormState(isEditing = goalId != null))
    val state: StateFlow<GoalFormState> = _state

    init {
        scope.launch {
            accountDao.observeAll().collect { accounts ->
                _state.value = _state.value.copy(availableAccounts = accounts)
            }
        }

        if (goalId != null) {
            scope.launch {
                goalDao.findById(goalId)?.let { goal ->
                    _state.value = _state.value.copy(
                        name = goal.name,
                        targetAmount = goal.targetAmount,
                        currency = goal.currency,
                        targetDate = goal.targetDate.orEmpty(),
                        color = goal.color.orEmpty(),
                        icon = goal.icon.orEmpty(),
                        notes = goal.notes.orEmpty()
                    )
                }
            }
        }
    }

    fun updateName(value: String) { _state.value = _state.value.copy(name = value) }
    fun updateTargetAmount(value: String) { _state.value = _state.value.copy(targetAmount = value) }
    fun updateCurrency(value: String) { _state.value = _state.value.copy(currency = value) }
    fun updateTargetDate(value: String) { _state.value = _state.value.copy(targetDate = value) }
    fun updateNotes(value: String) { _state.value = _state.value.copy(notes = value) }

    fun toggleAccountSelection(accountId: String) {
        val current = _state.value.selectedAccountIds.toMutableSet()
        if (current.contains(accountId)) {
            current.remove(accountId)
        } else {
            current.add(accountId)
        }
        _state.value = _state.value.copy(selectedAccountIds = current)
    }

    fun save(onSaved: () -> Unit) {
        val s = _state.value
        if (s.name.isBlank()) {
            _state.value = s.copy(error = "El nombre no puede estar vacío")
            return
        }
        if (s.targetAmount.isBlank() || s.targetAmount.toDoubleOrNull() == null || s.targetAmount.toDouble() <= 0) {
            _state.value = s.copy(error = "Ingresá un monto objetivo válido mayor a cero")
            return
        }
        if (!s.isEditing && s.selectedAccountIds.isEmpty()) {
            _state.value = s.copy(error = "Seleccioná al menos una cuenta vinculada para la meta")
            return
        }

        scope.launch {
            _state.value = s.copy(isSaving = true, error = null)
            val result = if (goalId != null) {
                val body = UpdateGoalBody(
                    name = s.name,
                    target_amount = s.targetAmount,
                    currency = s.currency.ifBlank { null },
                    target_date = s.targetDate.ifBlank { null },
                    color = s.color.ifBlank { null },
                    icon = s.icon.ifBlank { null },
                    notes = s.notes.ifBlank { null },
                    account_ids = if (s.selectedAccountIds.isNotEmpty()) s.selectedAccountIds.toList() else null
                )
                runCatching { api.updateGoal(goalId, body) }
            } else {
                val body = CreateGoalBody(
                    name = s.name,
                    target_amount = s.targetAmount,
                    currency = s.currency.ifBlank { null },
                    target_date = s.targetDate.ifBlank { null },
                    color = s.color.ifBlank { null },
                    icon = s.icon.ifBlank { null },
                    notes = s.notes.ifBlank { null },
                    account_ids = s.selectedAccountIds.toList()
                )
                runCatching { api.createGoal(body) }
            }

            result
                .onSuccess { remoteGoal ->
                    val entity = GoalEntity(
                        id = remoteGoal.id,
                        name = remoteGoal.name,
                        targetAmount = remoteGoal.target_amount ?: s.targetAmount,
                        currency = remoteGoal.currency ?: s.currency,
                        targetDate = remoteGoal.target_date,
                        color = remoteGoal.color,
                        icon = remoteGoal.icon,
                        notes = remoteGoal.notes,
                        state = remoteGoal.state,
                        progressBasis = remoteGoal.progress_basis,
                        currentBalance = remoteGoal.current_balance,
                        currentBalanceCents = remoteGoal.current_balance_cents,
                        remainingAmount = remoteGoal.remaining_amount,
                        remainingAmountCents = remoteGoal.remaining_amount_cents,
                        progressPercent = remoteGoal.progress_percent,
                        updatedAt = null
                    )
                    goalDao.upsertAll(listOf(entity))
                    onSaved()
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(isSaving = false, error = e.message ?: "Error al guardar")
                }
        }
    }
}
