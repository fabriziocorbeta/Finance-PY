package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.UpdateGoalBody
import py.com.cdco.financespy.db.GoalDao
import py.com.cdco.financespy.db.GoalEntity

data class GoalDetailState(
    val goal: GoalEntity? = null,
    val isDeleting: Boolean = false,
    val deleteError: String? = null,
    val isUpdatingState: Boolean = false,
    val stateError: String? = null
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
                    updatedAt = null
                )
                goalDao.upsertAll(listOf(updatedEntity))
                _state.value = _state.value.copy(goal = updatedEntity)
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
