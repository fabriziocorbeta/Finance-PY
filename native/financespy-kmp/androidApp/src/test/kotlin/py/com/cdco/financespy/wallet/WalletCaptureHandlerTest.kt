package py.com.cdco.financespy.wallet

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WalletCaptureHandlerTest {
    @Test
    fun acceptsRecentLocationWithinMaxAge() {
        val maxAge = 15 * 60_000L
        assertTrue(WalletCaptureHandler.isRecentEnoughLocation(0L, maxAge))
        assertTrue(WalletCaptureHandler.isRecentEnoughLocation(5 * 60_000L, maxAge))
        assertTrue(WalletCaptureHandler.isRecentEnoughLocation(maxAge, maxAge))
    }

    @Test
    fun rejectsStaleOrNegativeAgeLocations() {
        val maxAge = 15 * 60_000L
        assertFalse(WalletCaptureHandler.isRecentEnoughLocation(maxAge + 1L, maxAge))
        assertFalse(WalletCaptureHandler.isRecentEnoughLocation(-1L, maxAge))
    }
}
