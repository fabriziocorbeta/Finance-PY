package py.com.cdco.financespy.sync

import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity
import py.com.cdco.financespy.db.TransactionDao
import py.com.cdco.financespy.db.TransactionEntity

const val SYNC_WINDOW_DAYS = 90

class SyncEngine(
    private val api: FinancePyApi,
    private val accountDao: AccountDao,
    private val entryDao: EntryDao,
    private val transactionDao: TransactionDao,
    private val currentDateProvider: () -> String
) {
    suspend fun syncAll(): Result<Unit> = runCatching {
        syncAccounts()
        syncTransactions()
    }

    private suspend fun syncAccounts() {
        val remote = api.fetchAllAccounts()
        accountDao.upsertAll(remote.map { it.toEntity() })
        accountDao.deleteAllExcept(remote.map { it.id })
    }

    private suspend fun syncTransactions() {
        val startDate = subtractDays(currentDateProvider(), SYNC_WINDOW_DAYS)
        val remote = api.fetchRecentTransactions(startDate)
        entryDao.upsertAll(remote.map { it.toEntryEntity() })
        transactionDao.upsertAll(remote.map { it.toTransactionEntity() })
        entryDao.deleteStaleWithinWindow(remote.map { it.id }, startDate)
    }
}

private fun AccountDto.toEntity() = AccountEntity(
    id = id, name = name, balanceCents = balance_cents, cashBalanceCents = cash_balance_cents,
    currency = currency, classification = classification, accountType = account_type,
    subtype = subtype, status = status, updatedAt = updated_at
)

private fun TransactionListItemDto.toEntryEntity() = EntryEntity(
    id = id, accountId = account.id, date = date, name = name, amountCents = signed_amount_cents,
    currency = currency, entryableType = "Transaction", entryableId = id,
    parentEntryId = null, transferId = null, updatedAt = updated_at
)

private fun TransactionListItemDto.toTransactionEntity() = TransactionEntity(
    id = id, categoryId = category?.id, categoryName = category?.name,
    merchantId = merchant?.id, merchantName = merchant?.name, kind = "standard"
)
