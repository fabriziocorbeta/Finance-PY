package py.com.cdco.financespy.wallet

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class PendingCaptureStoreTest {
    @Test
    fun parsesOldJsonWithoutLatitudeLongitudeDeviceWithoutCrashing() {
        // Shape a capture queued before this feature existed would have on
        // disk -- no latitude/longitude/device keys at all.
        val old = JSONObject().apply {
            put("id", "abc-123")
            put("capturedAt", "2026-10-16T12:00:00Z")
            put("accountId", "acc-1")
            put("amount", "15000")
            put("merchant", "Super6")
            put("item", "MiTarjeta")
            put("nature", "EXPENSE")
        }

        val capture = parseCaptureJson(old)

        assertEquals("abc-123", capture.id)
        assertEquals("15000", capture.amount)
        assertNull(capture.latitude)
        assertNull(capture.longitude)
        assertNull(capture.device)
    }

    @Test
    fun parsesNewJsonWithLatitudeLongitudeDeviceCorrectly() {
        val new = JSONObject().apply {
            put("id", "abc-456")
            put("capturedAt", "2026-10-16T12:00:00Z")
            put("accountId", "acc-1")
            put("amount", "15000")
            put("merchant", "Super6")
            put("item", "MiTarjeta")
            put("nature", "EXPENSE")
            put("latitude", -25.2968)
            put("longitude", -57.5947)
            put("device", "SM-S928B")
        }

        val capture = parseCaptureJson(new)

        assertEquals(-25.2968, capture.latitude!!, 0.0001)
        assertEquals(-57.5947, capture.longitude!!, 0.0001)
        assertEquals("SM-S928B", capture.device)
    }

    @Test
    fun roundTripsThroughJsonWithLocationPreserved() {
        val original = PendingCapture(
            id = "xyz",
            capturedAt = "2026-10-16T12:00:00Z",
            accountId = "acc-1",
            amount = "15000",
            merchant = "Super6",
            item = "MiTarjeta",
            latitude = -25.2968,
            longitude = -57.5947,
            device = "SM-S928B"
        )

        val roundTripped = parseCaptureJson(captureToJson(original))

        assertEquals(original, roundTripped)
    }

    @Test
    fun roundTripsThroughJsonWithoutLocation() {
        val original = PendingCapture(
            id = "xyz",
            capturedAt = "2026-10-16T12:00:00Z",
            accountId = "acc-1",
            amount = "15000",
            merchant = "Super6",
            item = "MiTarjeta"
        )

        val json = captureToJson(original)
        assertEquals(false, json.has("latitude"))
        assertEquals(false, json.has("longitude"))
        assertEquals(false, json.has("device"))

        val roundTripped = parseCaptureJson(json)
        assertEquals(original, roundTripped)
    }
}
