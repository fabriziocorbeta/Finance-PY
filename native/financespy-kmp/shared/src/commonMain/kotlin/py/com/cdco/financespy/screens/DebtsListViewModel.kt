package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity

internal fun filterLiabilities(accounts: List<AccountEntity>): List<AccountEntity> =
    accounts.filter { it.classification == "liability" }

internal fun sumBalancesByCurrency(accounts: List<AccountEntity>): Map<String, Long> =
    accounts.groupBy { it.currency }.mapValues { (_, group) -> group.sumOf { it.balanceCents } }

// Las deudas (préstamos, tarjetas de crédito, otras obligaciones) ya existen
// como cuentas normales con classification == "liability", sincronizadas por
// SyncEngine (ver DashboardViewModel/TransactionsViewModel) -- esta pantalla
// solo filtra lo que ya está en Room, no duplica sync ni agrega su propio
// refresh(). El filtro y la suma viven como funciones top-level (arriba) para
// poder probarlos directo, sin pelear con el timing de stateIn/WhileSubscribed.
class DebtsListViewModel(
    scope: CoroutineScope,
    accountDao: AccountDao
) {
    val debts: StateFlow<List<AccountEntity>> = accountDao.observeAll()
        .map(::filterLiabilities)
        .stateIn(scope, SharingStarted.WhileSubscribed(5000), emptyList())

    val totalOwedByCurrency: StateFlow<Map<String, Long>> = debts
        .map(::sumBalancesByCurrency)
        .stateIn(scope, SharingStarted.WhileSubscribed(5000), emptyMap())
}
