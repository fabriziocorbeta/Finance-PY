package py.com.cdco.financespy.cache

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class OwnershipGuardTest {
    @Test
    fun noStoredOwnerNeverWipes() {
        assertFalse(OwnershipGuard.shouldWipe(storedOwnerId = null, currentOwnerId = "family-1"))
    }

    @Test
    fun unknownCurrentOwnerNeverWipes() {
        // Still starting up / not logged in yet -- must not nuke the queue.
        assertFalse(OwnershipGuard.shouldWipe(storedOwnerId = "family-1", currentOwnerId = null))
    }

    @Test
    fun sameOwnerDoesNotWipe() {
        assertFalse(OwnershipGuard.shouldWipe(storedOwnerId = "family-1", currentOwnerId = "family-1"))
    }

    @Test
    fun differentOwnerWipes() {
        assertTrue(OwnershipGuard.shouldWipe(storedOwnerId = "family-1", currentOwnerId = "family-2"))
    }
}
