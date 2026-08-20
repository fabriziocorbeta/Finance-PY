package py.com.cdco.financespy.sync

import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.RuleDto
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity
import py.com.cdco.financespy.db.RuleDao
import py.com.cdco.financespy.db.RuleEntity
import py.com.cdco.financespy.db.RuleRunDao
import py.com.cdco.financespy.db.RuleRunEntity
import py.com.cdco.financespy.db.TransactionDao
import py.com.cdco.financespy.db.TransactionEntity

const val SYNC_WINDOW_DAYS = 90

class SyncEngine(
    private val api: FinancePyApi,
    private val accountDao: AccountDao,
    private val entryDao: EntryDao,
    private val transactionDao: TransactionDao,
    private val ruleDao: RuleDao,
    private val ruleRunDao: RuleRunDao,
    private val currentDateProvider: () -> String
) {
    suspend fun syncAll(): Result<Unit> = runCatching {
        syncAccounts()
        syncTransactions()
        syncRules()
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

    private suspend fun syncRules() {
        val remote = api.fetchAllRules()
        val entities = remote.mapNotNull { it.toEntityOrNull() }
        ruleDao.upsertAll(entities)
        ruleDao.deleteAllExcept(entities.map { it.id })
        remote.forEach { rule ->
            val runs = runCatching { api.fetchRuleRuns(rule.id) }.getOrNull().orEmpty()
            ruleRunDao.upsertAll(runs.map {
                RuleRunEntity(
                    id = it.id, ruleId = it.rule_id, status = it.status,
                    executionType = it.execution_type, executedAt = it.executed_at ?: ""
                )
            })
        }
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

// Wave 1b solo soporta reglas de 1 condicion + 1 accion (ver spec). Una regla real
// del server con 0 o >1 condiciones/acciones (creada por la web, fuera del alcance
// de este cliente) no se puede representar en el schema aplanado de RuleEntity —
// se omite del sync en vez de crashear o truncar datos silenciosamente mal.
private fun RuleDto.toEntityOrNull(): RuleEntity? {
    val condition = conditions.firstOrNull() ?: return null
    val action = actions.firstOrNull() ?: return null
    if (conditions.size > 1 || actions.size > 1) return null
    return RuleEntity(
        id = id, name = name, resourceType = resource_type, active = active,
        conditionType = condition.condition_type, conditionOperator = condition.operator,
        conditionValue = condition.value ?: "",
        actionType = action.action_type, actionValue = action.value ?: "",
        updatedAt = updated_at
    )
}
