package py.com.cdco.financespy

import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.screens.filterLiabilities
import py.com.cdco.financespy.screens.sumBalancesByCurrency
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

private fun account(
    id: String,
    name: String,
    balanceCents: Long,
    currency: String,
    classification: String,
    accountType: String
) = AccountEntity(
    id = id,
    name = name,
    balanceCents = balanceCents,
    cashBalanceCents = balanceCents,
    currency = currency,
    classification = classification,
    accountType = accountType,
    subtype = null,
    status = "active",
    updatedAt = "2026-09-30T00:00:00Z"
)

// DebtsListViewModel's debts/totalOwedByCurrency are just a map() of these
// two functions over accountDao.observeAll() -- tested directly here instead
// of through stateIn(WhileSubscribed), which needs a live collector and
// virtual-time advancement to avoid racing the initial empty value.

class DebtsListViewModelTest {
    @Test
    fun onlyIncludesLiabilityAccounts() {
        val accounts = listOf(
            account("acc-1", "Cuenta corriente", 500_000, "PYG", "asset", "Depository"),
            account("acc-2", "Tarjeta Visa", 1_200_000, "PYG", "liability", "CreditCard"),
            account("acc-3", "Préstamo auto", 30_000_000, "PYG", "liability", "Loan")
        )

        val debts = filterLiabilities(accounts)

        assertEquals(2, debts.size)
        assertTrue(debts.none { it.classification == "asset" })
        assertTrue(debts.any { it.id == "acc-2" })
        assertTrue(debts.any { it.id == "acc-3" })
    }

    @Test
    fun totalsAreGroupedByCurrency() {
        val debts = listOf(
            account("acc-1", "Tarjeta Visa", 1_200_000, "PYG", "liability", "CreditCard"),
            account("acc-2", "Préstamo auto", 30_000_000, "PYG", "liability", "Loan"),
            account("acc-3", "Tarjeta USD", 500, "USD", "liability", "CreditCard")
        )

        val totals = sumBalancesByCurrency(debts)

        assertEquals(31_200_000L, totals["PYG"])
        assertEquals(500L, totals["USD"])
    }

    @Test
    fun emptyWhenNoLiabilities() {
        val accounts = listOf(account("acc-1", "Cuenta corriente", 500_000, "PYG", "asset", "Depository"))

        val debts = filterLiabilities(accounts)

        assertTrue(debts.isEmpty())
        assertTrue(sumBalancesByCurrency(debts).isEmpty())
    }
}
