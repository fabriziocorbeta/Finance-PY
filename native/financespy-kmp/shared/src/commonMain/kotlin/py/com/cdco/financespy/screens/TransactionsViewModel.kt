package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity

class TransactionsViewModel(
    scope: CoroutineScope,
    entryDao: EntryDao
) {
    private val _entries = MutableStateFlow<List<EntryEntity>>(emptyList())
    val entries: StateFlow<List<EntryEntity>> = _entries

    init {
        entryDao.observeAll().onEach { _entries.value = it }.launchIn(scope)
    }
}
