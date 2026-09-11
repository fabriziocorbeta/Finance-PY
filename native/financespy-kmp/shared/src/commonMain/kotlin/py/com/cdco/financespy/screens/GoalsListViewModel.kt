package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.db.GoalDao
import py.com.cdco.financespy.db.GoalEntity

class GoalsListViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    private val goalDao: GoalDao
) {
    val goals: StateFlow<List<GoalEntity>> = goalDao.observeAll()
        .stateIn(scope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun refresh() {
        scope.launch {
            runCatching {
                val remote = api.fetchAllGoals()
                val entities = remote.map { remoteGoal ->
                    GoalEntity(
                        id = remoteGoal.id,
                        name = remoteGoal.name,
                        targetAmount = remoteGoal.target_amount ?: "0",
                        currency = remoteGoal.currency ?: "USD",
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
                        pace = remoteGoal.pace,
                        status = remoteGoal.status,
                        monthsRemaining = remoteGoal.months_remaining,
                        catchUpDelta = remoteGoal.catch_up_delta,
                        updatedAt = null
                    )
                }
                goalDao.upsertAll(entities)
                goalDao.deleteAllExcept(entities.map { it.id })
            }
        }
    }
}
