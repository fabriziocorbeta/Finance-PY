package py.com.cdco.financespy.sync

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respondOk
import kotlinx.coroutines.test.runTest
import org.junit.Test
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.CreateTransactionBody
import py.com.cdco.financespy.api.dto.TransactionDetailDto
import kotlin.test.assertEquals

class OfflineOutboxTest {

    private class MemStore : OfflineStore {
        val map = mutableMapOf<String, String>()
        override fun get(key: String) = map[key]
        override fun put(key: String, value: String) { map[key] = value }
    }

    private class FakeApi : FinancePyApi(HttpClient(MockEngine { respondOk() })) {
        var reachable = false
        var failCreate = false
        var created = 0
        override suspend fun isServerReachable() = reachable
        override suspend fun createTransaction(body: CreateTransactionBody): TransactionDetailDto {
            if (failCreate) error("rejected")
            created++
            throw NotImplementedError() // result is unused by the outbox; counted above first
        }
    }

    private val body = CreateTransactionBody(
        account_id = "a", date = "2026-09-19", amount = "10", nature = "expense",
        name = "cafe", notes = null, category_id = null, merchant_id = null, tag_ids = emptyList()
    )

    @Test
    fun keepsItemsWhileServerIsDown() = runTest {
        val api = FakeApi()
        val outbox = OfflineOutbox(api, MemStore(), { 1L })
        outbox.enqueueTransaction(body, "cafe")
        assertEquals(1, outbox.pendingCount.value)
        assertEquals(0, outbox.flush())
        assertEquals(1, outbox.pendingCount.value)
    }

    @Test
    fun survivesRestartAndParksRejectedItems() = runTest {
        val api = FakeApi()
        val store = MemStore()
        OfflineOutbox(api, store, { 1L }).enqueueTransaction(body, "cafe")
        val reloaded = OfflineOutbox(api, store, { 2L })
        assertEquals(1, reloaded.pendingCount.value)

        api.reachable = true
        api.failCreate = true
        repeat(OUTBOX_MAX_ATTEMPTS) { reloaded.flush() }
        assertEquals(0, reloaded.pendingCount.value)
        assertEquals(1, reloaded.failedCount.value)
    }
}
