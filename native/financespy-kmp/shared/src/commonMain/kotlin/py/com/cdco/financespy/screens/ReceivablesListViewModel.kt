package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import py.com.cdco.financespy.db.ReceivableDao
import py.com.cdco.financespy.db.ReceivableEntity

class ReceivablesListViewModel(
    scope: CoroutineScope,
    receivableDao: ReceivableDao
) {
    val receivables: StateFlow<List<ReceivableEntity>> = receivableDao.observeAll()
        .stateIn(
            scope = scope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = emptyList()
        )
}
