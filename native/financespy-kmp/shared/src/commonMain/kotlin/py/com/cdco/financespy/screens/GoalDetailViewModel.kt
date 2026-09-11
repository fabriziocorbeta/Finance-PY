package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.CreateGoalPledgeBody
import py.com.cdco.financespy.api.dto.GoalPledgeDto
import py.com.cdco.financespy.api.dto.UpdateGoalBody
import py.com.cdco.financespy.db.GoalDao
import py.com.cdco.financespy.db.GoalEntity

data class GoalDetailState(
    val goal: GoalEntity? = null,
    val isDeleting: Boolean = false,
    val deleteError: String? = null,
    val isUpdatingState: Boolean = false,
    val stateError: String? = null,
    val pledges: List<GoalPledgeDto> = emptyList(),
    val isLoadingPledges: Boolean = false,
    val showPledgeDialog: Boolean = false,
    val pledgeAccounts: List<AccountDto> = emptyList(),
    val pledgeAccountId: String? = null,
    val pledgeAmount: String = "",
    val pledgeError: String? = null,
    val isSavingPledge: Boolean = false
)

class GoalDetailViewModel(
    private val scope: CoroutineScope,
    private val goalId: String,
    private val api: FinancePyApi,
    private val goalDao: GoalDao
) {
    private val _state = MutableStateFlow(GoalDetailState())
    val state: StateFlow<GoalDetailState> = _state

    init {
        scope.launch {
            val goal = goalDao.findById(goalId)
            _state.value = _state.value.copy(goal = goal)
            runCatching {
                val remote = api.fetchGoal(goalId)
                val updatedEntity = GoalEntity(
                    id = remote.id,
                    name = remote.name,
                    targetAmount = remote.target_amount ?: "0",
                    currency = remote.currency ?: "USD",
                    targetDate = remote.target_date,
                    color = remote.color,
                    icon = remote.icon,
                    notes = remote.notes,
                    state = remote.state,
                    progressBasis = remote.progress_basis,
                    currentBalance = remote.current_balance,
                    currentBalanceCents = remote.current_balance_cents,
                    remainingAmount = remote.remaining_amount,
                    remainingAmountCents = remote.remaining_amount_cents,
                    progressPercent = remote.progress_percent,
                    pace = remote.pace,
                    status = remote.status,
                    monthsRemaining = remote.months_remaining,
                    catchUpDelta = remote.catch_up_delta,
                    updatedAt = null
                )
                goalDao.upsertAll(listOf(updatedEntity))
                _state.value = _state.value.copy(goal = updatedEntity)
            }
        }
        loadPledges()
    }

    fun loadPledges() {
        scope.launch {
            _state.value = _state.value.copy(isLoadingPledges = true)
            runCatching {
                val pledges = api.fetchGoalPledges(goalId)
                _state.value = _state.value.copy(pledges = pledges, isLoadingPledges = false)
            }.onFailure {
                _state.value = _state.value.copy(isLoadingPledges = false)
            }
        }
    }

    fun openPledgeDialog() {
        scope.launch {
            runCatching {
                val allAccounts = api.fetchAllAccounts()
                val goalDto = runCatching { api.fetchGoal(goalId) }.getOrNull()
                val accountIds = goalDto?.account_ids
                val filtered = if (!accountIds.isNullOrEmpty()) {
                    allAccounts.filter { it.id in accountIds }
                } else {
                    allAccounts
                }
                _state.value = _state.value.copy(
                    pledgeAccounts = filtered,
                    pledgeAccountId = filtered.firstOrNull()?.id,
                    pledgeAmount = "",
                    pledgeError = null,
                    showPledgeDialog = true
                )
            }.onFailure { e ->
                _state.value = _state.value.copy(
                    pledgeError = e.message ?: "Error al cargar cuentas",
                    showPledgeDialog = true
                )
            }
        }
    }

    fun closePledgeDialog() {
        _state.value = _state.value.copy(showPledgeDialog = false, pledgeError = null)
    }

    fun updatePledgeAccount(id: String) {
        _state.value = _state.value.copy(pledgeAccountId = id)
    }

    fun updatePledgeAmount(amount: String) {
        _state.value = _state.value.copy(pledgeAmount = amount)
    }

    fun createPledge(onDone: () -> Unit = {}) {
        val accountId = _state.value.pledgeAccountId
        val amountDouble = _state.value.pledgeAmount.toDoubleOrNull()
        if (accountId == null) {
            _state.value = _state.value.copy(pledgeError = "Seleccioná una cuenta")
            return
        }
        if (amountDouble == null || amountDouble <= 0.0) {
            _state.value = _state.value.copy(pledgeError = "Ingresá un monto válido")
            return
        }

        scope.launch {
            _state.value = _state.value.copy(isSavingPledge = true, pledgeError = null)
            runCatching {
                api.createGoalPledge(goalId, CreateGoalPledgeBody(amount = amountDouble, account_id = accountId))
            }.onSuccess {
                _state.value = _state.value.copy(isSavingPledge = false, showPledgeDialog = false)
                loadPledges()
                onDone()
            }.onFailure { e ->
                _state.value = _state.value.copy(isSavingPledge = false, pledgeError = e.message ?: "Error al crear compromiso")
            }
        }
    }

    fun cancelPledge(pledgeId: String) {
        scope.launch {
            runCatching {
                api.cancelGoalPledge(goalId, pledgeId)
            }.onSuccess {
                loadPledges()
            }
        }
    }

    fun renewPledge(pledgeId: String) {
        scope.launch {
            runCatching {
                api.renewGoalPledge(goalId, pledgeId)
            }.onSuccess {
                loadPledges()
            }
        }
    }

    fun updateState(newState: String) {
        scope.launch {
            _state.value = _state.value.copy(isUpdatingState = true, stateError = null)
            runCatching {
                val updated = api.updateGoal(goalId, UpdateGoalBody(state = newState))
                val updatedEntity = GoalEntity(
                    id = updated.id,
                    name = updated.name,
                    targetAmount = updated.target_amount ?: "0",
                    currency = updated.currency ?: "USD",
                    targetDate = updated.target_date,
                    color = updated.color,
                    icon = updated.icon,
                    notes = updated.notes,
                    state = updated.state,
                    progressBasis = updated.progress_basis,
                    currentBalance = updated.current_balance,
                    currentBalanceCents = updated.current_balance_cents,
                    remainingAmount = updated.remaining_amount,
                    remainingAmountCents = updated.remaining_amount_cents,
                    progressPercent = updated.progress_percent,
                    pace = updated.pace,
                    status = updated.status,
                    monthsRemaining = updated.months_remaining,
                    catchUpDelta = updated.catch_up_delta,
                    updatedAt = null
                )
                goalDao.upsertAll(listOf(updatedEntity))
                _state.value = _state.value.copy(goal = updatedEntity, isUpdatingState = false)
            }.onFailure { e ->
                _state.value = _state.value.copy(isUpdatingState = false, stateError = e.message ?: "Error al actualizar estado")
            }
        }
    }

    fun delete(onDeleted: () -> Unit) {
        val current = _state.value.goal ?: return
        scope.launch {
            _state.value = _state.value.copy(isDeleting = true, deleteError = null)
            runCatching {
                if (current.state != "archived") {
                    api.updateGoal(goalId, UpdateGoalBody(state = "archived"))
                }
                api.deleteGoal(goalId)
                goalDao.deleteById(goalId)
            }.onSuccess {
                onDeleted()
            }.onFailure { e ->
                _state.value = _state.value.copy(isDeleting = false, deleteError = e.message ?: "Error al borrar meta")
            }
        }
    }
}
