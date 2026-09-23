package py.com.cdco.financespy.cache

import android.content.Context
import py.com.cdco.financespy.security.EncryptedPrefsFactory
import py.com.cdco.financespy.security.OwnerScope

class AndroidDashboardCache(
    context: Context,
    private val ownerId: () -> String? = { OwnerScope.currentOwnerId(context.applicationContext) }
) : DashboardCache {
    private val prefs = EncryptedPrefsFactory.create(context.applicationContext, "financespy_dashboard_cache")

    @Volatile private var lastCheckedOwner: String? = null

    override fun load(periodKey: String?): String? {
        ensureOwnerScope()
        return prefs.getString(keyFor(periodKey), null)
    }

    override fun save(periodKey: String?, json: String) {
        ensureOwnerScope()
        prefs.edit().putString(keyFor(periodKey), json).apply()
    }

    /** Drops every cached dashboard period. */
    fun wipeAll() {
        prefs.edit().clear().apply()
        lastCheckedOwner = null
    }

    private fun keyFor(periodKey: String?) = "dashboard_${periodKey ?: "default"}"

    private fun ensureOwnerScope() {
        val current = ownerId() ?: return
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
