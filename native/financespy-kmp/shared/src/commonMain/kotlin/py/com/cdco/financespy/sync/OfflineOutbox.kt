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
import py.com.cdco.financespy.api.dto.CreateFuelLogBody
import py.com.cdco.financespy.api.dto.CreateReceivableBody
import py.com.cdco.financespy.api.dto.CreateTransactionBody
import py.com.cdco.financespy.api.dto.CreateTransferBody
import py.com.cdco.financespy.api.dto.ProductDto
import py.com.cdco.financespy.api.dto.PurchaseOrderRequestDto
import py.com.cdco.financespy.api.dto.SaleRequestDto
import py.com.cdco.financespy.api.dto.UpdateTransactionBody
import kotlin.io.encoding.Base64
import kotlin.io.encoding.ExperimentalEncodingApi
import kotlin.math.abs
import kotlin.math.roundToLong

// Small key/value persistence. Deliberately NOT Room: the database uses
// destructive migrations, which would silently drop queued writes.
interface OfflineStore {
    fun get(key: String): String?
    fun put(key: String, value: String)
    /** Deletes a key. Default no-op keeps simple in-memory stores (tests) working. */
    fun remove(key: String) {}
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
    val lastError: String? = null,
    // Key (in OfflineStore) of a large binary attached to this item (invoice photo),
    // kept out of the queue list so every queue rewrite stays small.
    val blobKey: String? = null
)

@Serializable
private data class TransactionUpdateJob(val id: String, val body: UpdateTransactionBody)

@Serializable
private data class GoalPledgeJob(val goalId: String, val body: CreateGoalPledgeBody)

@Serializable
private data class SaleCreateJob(
    val payload: SaleRequestDto,
    val photoBase64: String? = null,
    val photoName: String? = null,
    val photoContentType: String? = null
)

@Serializable
private data class PurchaseOrderCreateJob(
    val payload: PurchaseOrderRequestDto,
    val photoBase64: String? = null,
    val photoName: String? = null,
    val photoContentType: String? = null
)

@Serializable
private data class SaleUpdateJob(
    val id: String,
    val payload: SaleRequestDto,
    val photoName: String? = null,
    val photoContentType: String? = null,
    val removePhoto: Boolean = false
)

@Serializable
private data class PurchaseOrderUpdateJob(
    val id: String,
    val payload: PurchaseOrderRequestDto,
    val photoName: String? = null,
    val photoContentType: String? = null,
    val removePhoto: Boolean = false
)

@Serializable
private data class RecordPhotoJob(
    val id: String,
    val photoName: String,
    val photoContentType: String
)

@Serializable
private data class FuelLogJob(val vehicleId: String, val body: CreateFuelLogBody)

@Serializable
private data class ProductUpdateJob(val id: String, val dto: ProductDto)

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
    suspend fun discard(itemId: String) = mutex.withLock {
        items.firstOrNull { it.id == itemId }?.blobKey?.let { runCatching { store.remove(it) } }
        persist(items.filter { it.id != itemId })
    }

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

    suspend fun enqueueSale(
        payload: SaleRequestDto,
        label: String,
        photoBytes: ByteArray? = null,
        photoName: String? = null,
        photoContentType: String? = null
    ) {
        val job = SaleCreateJob(payload = payload, photoName = photoName, photoContentType = photoContentType)
        enqueue("sale", json.encodeToString(SaleCreateJob.serializer(), job), label, photoBytes)
    }

    suspend fun enqueueSaleUpdate(
        id: String,
        payload: SaleRequestDto,
        label: String,
        photoBytes: ByteArray? = null,
        photoName: String? = null,
        photoContentType: String? = null,
        removePhoto: Boolean = false
    ) {
        val job = SaleUpdateJob(id, payload, photoName, photoContentType, removePhoto)
        enqueue("sale_update", json.encodeToString(SaleUpdateJob.serializer(), job), label, photoBytes)
    }

    suspend fun enqueueSaleAction(action: String, id: String, label: String) =
        enqueue("sale_$action", id, label) // action: complete | cancel | delete

    suspend fun enqueueSalePhoto(id: String, bytes: ByteArray, name: String, contentType: String, label: String) =
        enqueue("sale_photo", json.encodeToString(RecordPhotoJob.serializer(), RecordPhotoJob(id, name, contentType)), label, bytes)

    suspend fun enqueueSalePhotoDelete(id: String, label: String) = enqueue("sale_photo_delete", id, label)

    suspend fun enqueuePurchaseOrder(
        payload: PurchaseOrderRequestDto,
        label: String,
        photoBytes: ByteArray? = null,
        photoName: String? = null,
        photoContentType: String? = null
    ) {
        val job = PurchaseOrderCreateJob(payload = payload, photoName = photoName, photoContentType = photoContentType)
        enqueue("purchase_order", json.encodeToString(PurchaseOrderCreateJob.serializer(), job), label, photoBytes)
    }

    suspend fun enqueuePurchaseOrderUpdate(
        id: String,
        payload: PurchaseOrderRequestDto,
        label: String,
        photoBytes: ByteArray? = null,
        photoName: String? = null,
        photoContentType: String? = null,
        removePhoto: Boolean = false
    ) {
        val job = PurchaseOrderUpdateJob(id, payload, photoName, photoContentType, removePhoto)
        enqueue("purchase_order_update", json.encodeToString(PurchaseOrderUpdateJob.serializer(), job), label, photoBytes)
    }

    suspend fun enqueuePurchaseOrderAction(action: String, id: String, label: String) =
        enqueue("purchase_order_$action", id, label) // action: receive | cancel | delete

    suspend fun enqueuePurchaseOrderPhoto(id: String, bytes: ByteArray, name: String, contentType: String, label: String) =
        enqueue("purchase_order_photo", json.encodeToString(RecordPhotoJob.serializer(), RecordPhotoJob(id, name, contentType)), label, bytes)

    suspend fun enqueuePurchaseOrderPhotoDelete(id: String, label: String) = enqueue("purchase_order_photo_delete", id, label)

    suspend fun enqueueProduct(dto: ProductDto, label: String) =
        enqueue("product", json.encodeToString(ProductDto.serializer(), dto), label)

    suspend fun enqueueProductUpdate(id: String, dto: ProductDto, label: String) =
        enqueue("product_update", json.encodeToString(ProductUpdateJob.serializer(), ProductUpdateJob(id, dto)), label)

    suspend fun enqueueProductDelete(id: String, label: String) = enqueue("product_delete", id, label)

    suspend fun enqueueFuelLog(vehicleId: String, body: CreateFuelLogBody, label: String) =
        enqueue("fuel_log", json.encodeToString(FuelLogJob.serializer(), FuelLogJob(vehicleId, body)), label)

    @OptIn(ExperimentalEncodingApi::class)
    private suspend fun enqueue(kind: String, payload: String, label: String, blob: ByteArray? = null) = mutex.withLock {
        val t = now()
        val itemId = "$t-${items.size}"
        val blobKey = blob?.let { "outbox_blob_$itemId" }
        if (blobKey != null && blob != null) store.put(blobKey, Base64.encode(blob))
        persist(items + OutboxItem(id = itemId, kind = kind, payload = payload, label = label, createdAt = t, blobKey = blobKey))
    }

    /** Sends queued items in order. Returns how many were delivered. */
    suspend fun flush(): Int {
        var sent = 0
        mutex.withLock {
            for (item in items.filter { !it.failed }) {
                val result = runCatching { send(item) }
                if (result.isSuccess) {
                    item.blobKey?.let { runCatching { store.remove(it) } }
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

    @OptIn(ExperimentalEncodingApi::class)
    private fun readBlob(item: OutboxItem): ByteArray? =
        item.blobKey?.let { key -> store.get(key)?.let { runCatching { Base64.decode(it) }.getOrNull() } }

    /**
     * The record itself was created but its invoice photo could not be uploaded: queue
     * ONLY the photo as a follow-up. Retrying the whole job would create a duplicate.
     * Called from inside flush(), which already holds the mutex.
     */
    @OptIn(ExperimentalEncodingApi::class)
    private fun queuePhotoFollowUp(kind: String, recordId: String, bytes: ByteArray, name: String, contentType: String, label: String) {
        val t = now()
        val itemId = "$t-${items.size}-photo"
        val blobKey = "outbox_blob_$itemId"
        store.put(blobKey, Base64.encode(bytes))
        persist(items + OutboxItem(
            id = itemId, kind = kind,
            payload = json.encodeToString(RecordPhotoJob.serializer(), RecordPhotoJob(recordId, name, contentType)),
            label = label, createdAt = t, blobKey = blobKey
        ))
    }

    @OptIn(ExperimentalEncodingApi::class)
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

            "sale" -> {
                val job = json.decodeFromString(SaleCreateJob.serializer(), item.payload)
                val created = api.createSale(job.payload)
                // Legacy items kept the photo inline (photoBase64); new ones use blobKey.
                val bytes = readBlob(item) ?: job.photoBase64?.let { runCatching { Base64.decode(it) }.getOrNull() }
                if (bytes != null) {
                    val name = job.photoName ?: "factura_venta.jpg"
                    val type = job.photoContentType ?: "image/jpeg"
                    runCatching { api.uploadSaleInvoicePhoto(created.id, bytes, name, type) }
                        .onFailure {
                            if (it is CancellationException) throw it
                            queuePhotoFollowUp("sale_photo", created.id, bytes, name, type, "Factura de venta #${created.sale_number ?: ""}")
                        }
                }
            }
            "sale_update" -> {
                val job = json.decodeFromString(SaleUpdateJob.serializer(), item.payload)
                api.updateSale(job.id, job.payload)
                val bytes = readBlob(item)
                if (bytes != null) {
                    val name = job.photoName ?: "factura_venta.jpg"
                    val type = job.photoContentType ?: "image/jpeg"
                    runCatching { api.uploadSaleInvoicePhoto(job.id, bytes, name, type) }
                        .onFailure {
                            if (it is CancellationException) throw it
                            queuePhotoFollowUp("sale_photo", job.id, bytes, name, type, "Factura de venta")
                        }
                } else if (job.removePhoto) {
                    api.deleteSaleInvoicePhoto(job.id)
                }
            }
            "sale_complete" -> api.completeSale(item.payload)
            "sale_cancel" -> api.cancelSale(item.payload)
            "sale_delete" -> api.deleteSale(item.payload)
            "sale_photo" -> {
                val job = json.decodeFromString(RecordPhotoJob.serializer(), item.payload)
                val bytes = readBlob(item) ?: error("photo data missing")
                api.uploadSaleInvoicePhoto(job.id, bytes, job.photoName, job.photoContentType)
            }
            "sale_photo_delete" -> api.deleteSaleInvoicePhoto(item.payload)

            "purchase_order" -> {
                val job = json.decodeFromString(PurchaseOrderCreateJob.serializer(), item.payload)
                val created = api.createPurchaseOrder(job.payload)
                val bytes = readBlob(item) ?: job.photoBase64?.let { runCatching { Base64.decode(it) }.getOrNull() }
                if (bytes != null) {
                    val name = job.photoName ?: "factura_compra.jpg"
                    val type = job.photoContentType ?: "image/jpeg"
                    runCatching { api.uploadPurchaseOrderInvoicePhoto(created.id, bytes, name, type) }
                        .onFailure {
                            if (it is CancellationException) throw it
                            queuePhotoFollowUp("purchase_order_photo", created.id, bytes, name, type, "Factura de orden #${created.order_number ?: ""}")
                        }
                }
            }
            "purchase_order_update" -> {
                val job = json.decodeFromString(PurchaseOrderUpdateJob.serializer(), item.payload)
                api.updatePurchaseOrder(job.id, job.payload)
                val bytes = readBlob(item)
                if (bytes != null) {
                    val name = job.photoName ?: "factura_compra.jpg"
                    val type = job.photoContentType ?: "image/jpeg"
                    runCatching { api.uploadPurchaseOrderInvoicePhoto(job.id, bytes, name, type) }
                        .onFailure {
                            if (it is CancellationException) throw it
                            queuePhotoFollowUp("purchase_order_photo", job.id, bytes, name, type, "Factura de orden de compra")
                        }
                } else if (job.removePhoto) {
                    api.deletePurchaseOrderInvoicePhoto(job.id)
                }
            }
            "purchase_order_receive" -> api.receivePurchaseOrder(item.payload)
            "purchase_order_cancel" -> api.cancelPurchaseOrder(item.payload)
            "purchase_order_delete" -> api.deletePurchaseOrder(item.payload)
            "purchase_order_photo" -> {
                val job = json.decodeFromString(RecordPhotoJob.serializer(), item.payload)
                val bytes = readBlob(item) ?: error("photo data missing")
                api.uploadPurchaseOrderInvoicePhoto(job.id, bytes, job.photoName, job.photoContentType)
            }
            "purchase_order_photo_delete" -> api.deletePurchaseOrderInvoicePhoto(item.payload)

            "product" -> api.createProduct(json.decodeFromString(ProductDto.serializer(), item.payload))
            "product_update" -> json.decodeFromString(ProductUpdateJob.serializer(), item.payload).let {
                api.updateProduct(it.id, it.dto)
            }
            "product_delete" -> api.deleteProduct(item.payload)
            "fuel_log" -> json.decodeFromString(FuelLogJob.serializer(), item.payload).let {
                api.createFuelLog(it.vehicleId, it.body)
            }
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
