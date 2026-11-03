package py.com.cdco.financespy.wallet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SeenNotificationPartsStoreTest {
    private val ttl = 6 * 60 * 60 * 1000L
    private val maxEntries = 500

    @Test
    fun firstTimeSeeingPartsAllAreNew() {
        val (newParts, stored) = filterNewParts(
            storedEntries = emptyList(),
            parts = listOf("TRANS. APROBADA ... OVEJA NEGRA SRL LUQUE ... monto: 65.000-"),
            now = 1_000L,
            ttlMillis = ttl,
            maxEntries = maxEntries
        )

        assertEquals(1, newParts.size)
        assertEquals(1, stored.size)
    }

    @Test
    fun reseeingExactSamePartWithinTtlIsNotNew() {
        val part = "TRANS. APROBADA ... OVEJA NEGRA SRL LUQUE ... monto: 65.000-"
        val (_, afterFirst) = filterNewParts(emptyList(), listOf(part), now = 1_000L, ttlMillis = ttl, maxEntries = maxEntries)

        // Notification reposted 1 second later with the same message still in its history.
        val (newParts, _) = filterNewParts(afterFirst, listOf(part), now = 2_000L, ttlMillis = ttl, maxEntries = maxEntries)

        assertTrue(newParts.isEmpty())
    }

    @Test
    fun onlyGenuinelyNewPartsAreReturnedFromAMixedRepost() {
        val oldPart = "TRANS. APROBADA ... COMERCIAL EL CACIQUE ... monto: 372.250-"
        val newPart = "TRANS. APROBADA ... COMBU BAR COMPANY ... monto: 361.048-"
        val (_, afterFirst) = filterNewParts(emptyList(), listOf(oldPart), now = 1_000L, ttlMillis = ttl, maxEntries = maxEntries)

        // The SMS thread notification reposts with both the already-seen
        // message AND a brand new one appended.
        val (newParts, _) = filterNewParts(afterFirst, listOf(oldPart, newPart), now = 60_000L, ttlMillis = ttl, maxEntries = maxEntries)

        assertEquals(listOf(newPart), newParts)
    }

    @Test
    fun partOutsideTtlWindowIsTreatedAsNewAgain() {
        val part = "TRANS. APROBADA ... OVEJA NEGRA SRL LUQUE ... monto: 65.000-"
        val (_, afterFirst) = filterNewParts(emptyList(), listOf(part), now = 0L, ttlMillis = ttl, maxEntries = maxEntries)

        // A real second purchase, identical amount/merchant, the next day --
        // must NOT be silently dropped as a "duplicate" of yesterday's.
        val (newParts, _) = filterNewParts(afterFirst, listOf(part), now = ttl + 1_000L, ttlMillis = ttl, maxEntries = maxEntries)

        assertEquals(listOf(part), newParts)
    }

    @Test
    fun storeIsCappedAtMaxEntries() {
        val cap = 3
        var entries = emptyList<SeenPartEntry>()
        repeat(5) { i ->
            val (_, updated) = filterNewParts(entries, listOf("part-$i"), now = i.toLong(), ttlMillis = ttl, maxEntries = cap)
            entries = updated
        }

        assertEquals(cap, entries.size)
        // Oldest entries (part-0, part-1) were evicted; most recent survive.
        assertEquals(listOf("part-2", "part-3", "part-4").map { hashOfNotificationPart(it) }, entries.map { it.hash })
    }

    @Test
    fun emptyPartsListReturnsEmptyAndDoesNotTouchStoredEntries() {
        val existing = listOf(SeenPartEntry(hashOfNotificationPart("x"), 500L))

        val (newParts, stored) = filterNewParts(existing, emptyList(), now = 1_000L, ttlMillis = ttl, maxEntries = maxEntries)

        assertTrue(newParts.isEmpty())
        assertEquals(existing, stored)
    }

    @Test
    fun jsonRoundTripPreservesEntries() {
        val entries = listOf(SeenPartEntry(hashOfNotificationPart("a"), 111L), SeenPartEntry(hashOfNotificationPart("b"), 222L))

        val roundTripped = parseSeenEntriesJson(seenEntriesToJson(entries))

        assertEquals(entries, roundTripped)
    }

    @Test
    fun malformedJsonParsesAsEmptyWithoutCrashing() {
        assertEquals(emptyList<SeenPartEntry>(), parseSeenEntriesJson("not json"))
    }
}
