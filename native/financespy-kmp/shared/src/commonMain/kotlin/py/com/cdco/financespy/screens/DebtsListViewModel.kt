package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity

// Las deudas (préstamos, tarjetas de crédito, otras obligaciones) ya existen
// como cuentas normales con classification == "liability", sincronizadas por
// SyncEngine (ver DashboardViewModel/TransactionsViewModel) -- esta pantalla
// solo filtra lo que ya está en Room, no duplica sync ni agrega su propio
// refresh().
class DebtsListViewModel(
    scope: CoroutineScope,
    accountDao: AccountDao
) {
    val debts: StateFlow<List<AccountEntity>> = accountDao.observeAll()
        .map { accounts -> accounts.filter { it.classification == "liability" } }
        .stateIn(scope, SharingStarted.WhileSubscribed(5000), emptyList())

    val totalOwedByCurrency: StateFlow<Map<String, Long>> = debts
        .map { list -> list.groupBy { it.currency }.mapValues { (_, accounts) -> accounts.sumOf { it.balanceCents } } }
        .stateIn(scope, SharingStarted.WhileSubscribed(5000), emptyMap())
}
