package py.com.cdco.financespy.cache

import android.content.Context
import py.com.cdco.financespy.security.EncryptedPrefsFactory
import py.com.cdco.financespy.security.OwnerScope
import py.com.cdco.financespy.sync.OfflineStore

class AndroidOfflineStore(
    context: Context,
    // Overridable for tests; defaults to the real device-wide owner marker.
    private val ownerId: () -> String? = { OwnerScope.currentOwnerId(context.applicationContext) }
) : OfflineStore {
    private val appContext = context.applicationContext
    private val prefs = EncryptedPrefsFactory.create(appContext, "financespy_offline_store")

    // In-memory only, to skip the owner check's SharedPreferences read/write
    // on every single get/put once we've already confirmed the owner for
    // this process lifetime.
    @Volatile private var lastCheckedOwner: String? = null

    override fun get(key: String): String? {
        ensureOwnerScope()
        return prefs.getString(key, null)
    }

    override fun put(key: String, value: String) {
        ensureOwnerScope()
        prefs.edit().putString(key, value).apply()
    }

    /** Drops everything: the outbox queue and every cached reference list. */
    fun wipeAll() {
        prefs.edit().clear().apply()
        lastCheckedOwner = null
    }

    private fun ensureOwnerScope() {
        val current = ownerId() ?: return // not logged in / unknown yet: leave data as-is
        if (current == lastCheckedOwner) return

        val stored = prefs.getString(OWNER_KEY, null)
        if (OwnershipGuard.shouldWipe(stored, current)) {
            prefs.edit().clear().putString(OWNER_KEY, current).apply()
        } else if (stored == null) {
            prefs.edit().putString(OWNER_KEY, current).apply()
        }
        lastCheckedOwner = current
    }

    private companion object {
        const val OWNER_KEY = "_owner_family_id"
    }
}
