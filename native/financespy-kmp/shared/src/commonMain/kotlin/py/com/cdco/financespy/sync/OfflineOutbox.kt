package py.com.cdco.financespy.sync

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull
import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.CreateGoalBody
import py.com.cdco.financespy.api.dto.CreateGoalPledgeBody
import py.com.cdco.financespy.api.dto.CreateReceivableBody
import py.com.cdco.financespy.api.dto.CreateTransactionBody
import py.com.cdco.financespy.api.dto.CreateTransferBody
import py.com.cdco.financespy.api.dto.UpdateTransactionBody
import kotlin.math.abs
import kotlin.math.roundToLong

// Small key/value persistence. Deliberately NOT Room: the database uses
// destructive migrations, which would silently drop queued writes.
interface OfflineStore {
    fun get(key: String): String?
    fun put(key: String, value: String)
}

@Serializable
data class OutboxItem(
    val id: String,
    val kind: String,
    val payload: String,
    val label: String,
    val createdAt: Long,
    val attempts: Int = 0,
    val failed: Boolean = false,
    val lastError: String? = null
)

@Serializable
private data class TransactionUpdateJob(val id: String, val body: UpdateTransactionBody)

@Serializable
private data class GoalPledgeJob(val goalId: String, val body: CreateGoalPledgeBody)

const val OUTBOX_MAX_ATTEMPTS = 3

/**
 * Queue of create-requests made while the server is unreachable.
 *
 * A write is only queued when a reachability probe confirms the server is
 * down/unreachable, so a request that may already have been processed is
 * never replayed (no duplicates). Items flush in order; the first
 * unreachable result stops the run.
 */
class OfflineOutbox(
    private val api: FinancePyApi,
    private val store: OfflineStore,
    private val now: () -> Long,
    private val onFlushed: suspend () -> Unit = {}
) {
    private val json = Json { ignoreUnknownKeys = true; isLenient = true }
    private val mutex = Mutex()
    private var items: List<OutboxItem> = load()
    private val _items = MutableStateFlow(items)
    val pendingItems: StateFlow<List<OutboxItem>> = _items
    private val _pending = MutableStateFlow(items.count { !it.failed })
    private val _failed = MutableStateFlow(items.count { it.failed })
    val pendingCount: StateFlow<Int> = _pending
    val failedCount: StateFlow<Int> = _failed

    private fun load(): List<OutboxItem> = runCatching {
        store.get(KEY)?.let { json.decodeFromString(ListSerializer(OutboxItem.serializer()), it) }
    }.getOrNull() ?: emptyList()

    private fun persist(next: List<OutboxItem>) {
        items = next
        _items.value = next
        store.put(KEY, json.encodeToString(ListSerializer(OutboxItem.serializer()), next))
        _pending.value = next.count { !it.failed }
        _failed.value = next.count { it.failed }
    }

    suspend fun shouldQueue(error: Throwable): Boolean =
        error !is CancellationException && !api.isServerReachable()

    suspend fun enqueueTransaction(body: CreateTransactionBody, label: String) =
        enqueue("transaction", json.encodeToString(CreateTransactionBody.serializer(), body), label)

    suspend fun enqueueTransactionUpdate(id: String, body: UpdateTransactionBody, label: String) =
        enqueue("transaction_update", json.encodeToString(TransactionUpdateJob.serializer(), TransactionUpdateJob(id, body)), label)

    suspend fun enqueueTransactionDelete(id: String, label: String) =
        enqueue("transaction_delete", id, label)

    /** Drop a queued item (user discards a pending row). */
    suspend fun discard(itemId: String) = mutex.withLock { persist(items.filter { it.id != itemId }) }

    fun decodeTransaction(item: OutboxItem): CreateTransactionBody? =
        if (item.kind != "transaction") null
        else runCatching { json.decodeFromString(CreateTransactionBody.serializer(), item.payload) }.getOrNull()

    suspend fun enqueueTransfer(body: CreateTransferBody, label: String) =
        enqueue("transfer", json.encodeToString(CreateTransferBody.serializer(), body), label)

    suspend fun enqueueGoalPledge(goalId: String, body: CreateGoalPledgeBody, label: String) =
        enqueue("goal_pledge", json.encodeToString(GoalPledgeJob.serializer(), GoalPledgeJob(goalId, body)), label)

    suspend fun enqueueReceivable(body: CreateReceivableBody, label: String) =
        enqueue("receivable", json.encodeToString(CreateReceivableBody.serializer(), body), label)

    suspend fun enqueueGoal(body: CreateGoalBody, label: String) =
        enqueue("goal", json.encodeToString(CreateGoalBody.serializer(), body), label)

    private suspend fun enqueue(kind: String, payload: String, label: String) = mutex.withLock {
        val t = now()
        persist(items + OutboxItem(id = "$t-${items.size}", kind = kind, payload = payload, label = label, createdAt = t))
    }

    /** Sends queued items in order. Returns how many were delivered. */
    suspend fun flush(): Int {
        var sent = 0
        mutex.withLock {
            for (item in items.filter { !it.failed }) {
                val result = runCatching { send(item) }
                if (result.isSuccess) {
                    persist(items.filter { it.id != item.id })
                    sent++
                    continue
                }
                val error = result.exceptionOrNull()
                if (error is CancellationException) throw error
                if (!api.isServerReachable()) break
                // Server is up and rejected/failed it: count the attempt, park it
                // as failed after a few so it stops blocking and the user sees it.
                val attempts = item.attempts + 1
                persist(items.map {
                    if (it.id == item.id) it.copy(
                        attempts = attempts,
                        failed = attempts >= OUTBOX_MAX_ATTEMPTS,
                        lastError = error?.message
                    ) else it
                })
            }
        }
        if (sent > 0) runCatching { onFlushed() }
        return sent
    }

    private suspend fun send(item: OutboxItem) {
        when (item.kind) {
            "transaction" -> api.createTransaction(json.decodeFromString(CreateTransactionBody.serializer(), item.payload))
            "transaction_update" -> json.decodeFromString(TransactionUpdateJob.serializer(), item.payload).let {
                api.updateTransaction(it.id, it.body)
            }
            "transfer" -> api.createTransfer(json.decodeFromString(CreateTransferBody.serializer(), item.payload))
            "transaction_delete" -> api.deleteTransaction(item.payload)
            "goal_pledge" -> json.decodeFromString(GoalPledgeJob.serializer(), item.payload).let {
                api.createGoalPledge(it.goalId, it.body)
            }
            "receivable" -> api.createReceivable(json.decodeFromString(CreateReceivableBody.serializer(), item.payload))
            "goal" -> api.createGoal(json.decodeFromString(CreateGoalBody.serializer(), item.payload))
            else -> error("unknown outbox kind ${item.kind}")
        }
    }

    /**
     * Fetch a reference list (accounts, categories...) and remember it; when
     * the server does not answer quickly, serve the last remembered copy so
     * forms still open offline.
     */
    suspend fun <T> cachedList(key: String, serializer: KSerializer<T>, fetch: suspend () -> List<T>): List<T> {
        val fresh = withTimeoutOrNull(5_000L) { runCatching { fetch() }.getOrNull() }
        if (fresh != null) {
            runCatching { store.put("ref_$key", json.encodeToString(ListSerializer(serializer), fresh)) }
            return fresh
        }
        return runCatching {
            store.get("ref_$key")?.let { json.decodeFromString(ListSerializer(serializer), it) }
        }.getOrNull() ?: emptyList()
    }

    private companion object {
        const val KEY = "outbox_items"
    }
}

/** Server amount string ("1500" / "12.50") -> minor units, PYG has none. */
fun amountTextToCents(text: String, currency: String?): Long {
    val d = text.toDoubleOrNull() ?: 0.0
    return if (isZeroMinorUnit(currency)) d.roundToLong() else (d * 100.0).roundToLong()
}

/** Minor units -> the plain amount string the API expects. */
fun centsToAmountText(cents: Long, currency: String?): String {
    val a = abs(cents)
    if (isZeroMinorUnit(currency)) return a.toString()
    val c = a % 100
    return "${a / 100}.${if (c < 10) "0$c" else "$c"}"
}

private fun isZeroMinorUnit(currency: String?) = currency?.uppercase() in listOf("PYG", "GUARANI", "GUARANIES")
