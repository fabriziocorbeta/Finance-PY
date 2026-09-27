package py.com.cdco.financespy.sync

import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.GoalDto
import py.com.cdco.financespy.api.dto.RuleDto
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.EntryEntity
import py.com.cdco.financespy.api.dto.ReceivableDto
import py.com.cdco.financespy.db.GoalDao
import py.com.cdco.financespy.db.GoalEntity
import py.com.cdco.financespy.db.ReceivableDao
import py.com.cdco.financespy.db.ReceivableEntity
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
    private val goalDao: GoalDao? = null,
    private val receivableDao: ReceivableDao? = null,
    private val currentDateProvider: () -> String
) {
    // The 5 syncs hit independent endpoints and write to independent tables
    // (no FK enforced between EntryEntity.accountId and AccountEntity at the
    // Room level, confirmed no @ForeignKey on EntryEntity/TransactionEntity),
    // so there is no correctness reason to run them one after another. Doing
    // so only added up their latencies -- a dashboard refresh waited for the
    // slowest possible sum of 5 sequential requests (plus one more per rule
    // inside syncRules) before the screen could show anything current.
    suspend fun syncAll(): Result<Unit> = runCatching {
        coroutineScope {
            val accounts = async { syncAccounts() }
            val transactions = async { syncTransactions() }
            val rules = async { syncRules() }
            val goals = async { syncGoals() }
            val receivables = async { syncReceivables() }
            accounts.await()
            transactions.await()
            rules.await()
            goals.await()
            receivables.await()
        }
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
        // One fetchRuleRuns call per rule, same reasoning as syncAll: these are
        // independent requests with no ordering dependency between them.
        coroutineScope {
            remote.map { rule ->
                async {
                    val runs = runCatching { api.fetchRuleRuns(rule.id) }.getOrNull().orEmpty()
                    ruleRunDao.upsertAll(runs.map {
                        RuleRunEntity(
                            id = it.id, ruleId = it.rule_id, status = it.status,
                            executionType = it.execution_type, executedAt = it.executed_at ?: ""
                        )
                    })
                }
            }.forEach { it.await() }
        }
    }

    suspend fun syncGoals() {
        val dao = goalDao ?: return
        val remote = api.fetchAllGoals()
        val entities = remote.map { it.toEntity() }
        dao.upsertAll(entities)
        dao.deleteAllExcept(entities.map { it.id })
    }

    suspend fun syncReceivables() {
        val dao = receivableDao ?: return
        val remote = api.fetchAllReceivables()
        val entities = remote.map { it.toEntity() }
        dao.upsertAll(entities)
        dao.deleteAllExcept(entities.map { it.id })
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

private fun GoalDto.toEntity() = GoalEntity(
    id = id,
    name = name,
    targetAmount = target_amount ?: "0",
    currency = currency ?: "USD",
    targetDate = target_date,
    color = color,
    icon = icon,
    notes = notes,
    state = state,
    progressBasis = progress_basis,
    currentBalance = current_balance,
    currentBalanceCents = current_balance_cents,
    remainingAmount = remaining_amount,
    remainingAmountCents = remaining_amount_cents,
    progressPercent = progress_percent,
    pace = pace,
    status = status,
    monthsRemaining = months_remaining,
    catchUpDelta = catch_up_delta,
    updatedAt = null
)

private fun ReceivableDto.toEntity() = ReceivableEntity(
    id = id,
    name = name ?: "(sin nombre)",
    totalAmount = total_amount ?: 0.0,
    balance = balance ?: 0.0,
    balanceCents = balance_cents ?: 0L,
    originalBalance = original_balance ?: 0.0,
    originalBalanceCents = original_balance_cents ?: 0L,
    paidAmount = paid_amount ?: 0.0,
    paidAmountCents = paid_amount_cents ?: 0L,
    percentPaid = percent_paid ?: 0.0,
    installmentCount = installment_count,
    dueDay = due_day,
    currency = currency ?: "PYG",
    notes = notes,
    updatedAt = updated_at ?: "",
    installmentScheduleJson = installment_schedule?.let { kotlinx.serialization.json.Json.encodeToString(kotlinx.serialization.builtins.ListSerializer(py.com.cdco.financespy.api.dto.InstallmentDto.serializer()), it) }
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
