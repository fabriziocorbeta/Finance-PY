package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.BalanceSeriesDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity

data class AccountDetailState(
    val account: AccountEntity? = null,
    val entries: List<EntryEntity> = emptyList(),
    val balanceSeries: BalanceSeriesDto? = null,
    val isLoadingSeries: Boolean = false,
    val seriesPeriod: String = "last_30_days"
)

class AccountDetailViewModel(
    private val scope: CoroutineScope,
    private val accountId: String,
    accountDao: AccountDao,
    entryDao: EntryDao,
    private val api: FinancePyApi? = null
) {
    private val _state = MutableStateFlow(AccountDetailState())
    val state: StateFlow<AccountDetailState> = _state

    init {
        combine(accountDao.observeAll(), entryDao.observeByAccountId(accountId)) { accounts, entries ->
            val acct = accounts.firstOrNull { it.id == accountId }
            _state.value.copy(account = acct, entries = entries)
        }.onEach { _state.value = it }.launchIn(scope)

        loadBalanceSeries()
    }

    fun loadBalanceSeries(period: String = _state.value.seriesPeriod) {
        if (api == null) return
        _state.value = _state.value.copy(isLoadingSeries = true, seriesPeriod = period)
        scope.launch {
            try {
                val series = api.fetchAccountBalanceSeries(accountId, period)
                _state.value = _state.value.copy(
                    balanceSeries = series,
                    isLoadingSeries = false
                )
            } catch (e: Exception) {
                _state.value = _state.value.copy(isLoadingSeries = false)
            }
        }
    }

    fun changePeriod(period: String) {
        if (_state.value.seriesPeriod != period) {
            loadBalanceSeries(period)
        }
    }
}
