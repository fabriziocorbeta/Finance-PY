package py.com.cdco.financespy.cache

// Decides whether locally persisted data (offline outbox, dashboard cache,
// Wallet pending captures) belongs to whoever is currently logged in.
//
// Pure/platform-agnostic on purpose: the actual storage (SharedPreferences on
// Android) lives next to each store, but the "does this still belong to the
// current user?" decision is the same everywhere and is worth testing
// without an Android runtime.
object OwnershipGuard {
    /**
     * @param storedOwnerId owner id (family id) recorded alongside the data
     *   the last time it was written, or null if nothing was ever recorded
     *   (fresh install, or data written before ownership tracking existed).
     * @param currentOwnerId owner id of whoever is logged in right now, or
     *   null if that isn't known yet (e.g. still starting up).
     * @return true when the stored data was written for a different owner
     *   and must be discarded before it's shown to the current user.
     *
     * A null on either side is deliberately never treated as a mismatch:
     * we only ever wipe on a *confirmed* different owner, never on "we don't
     * know yet" -- that would nuke the offline queue on every cold start.
     */
    fun shouldWipe(storedOwnerId: String?, currentOwnerId: String?): Boolean =
        storedOwnerId != null && currentOwnerId != null && storedOwnerId != currentOwnerId
}
