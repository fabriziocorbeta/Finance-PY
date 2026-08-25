package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import py.com.cdco.financespy.db.GoalDao
import py.com.cdco.financespy.db.GoalEntity

class GoalsListViewModel(
    scope: CoroutineScope,
    goalDao: GoalDao
) {
    val goals: StateFlow<List<GoalEntity>> = goalDao.observeAll()
        .stateIn(scope, SharingStarted.WhileSubscribed(5000), emptyList())
}
