package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity

data class AccountDetailState(
    val account: AccountEntity? = null,
    val entries: List<EntryEntity> = emptyList()
)

class AccountDetailViewModel(
    scope: CoroutineScope,
    accountId: String,
    accountDao: AccountDao,
    entryDao: EntryDao
) {
    private val _state = MutableStateFlow(AccountDetailState())
    val state: StateFlow<AccountDetailState> = _state

    init {
        combine(accountDao.observeAll(), entryDao.observeByAccountId(accountId)) { accounts, entries ->
            AccountDetailState(account = accounts.firstOrNull { it.id == accountId }, entries = entries)
        }.onEach { _state.value = it }.launchIn(scope)
    }
}
