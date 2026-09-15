package py.com.cdco.financespy.cache

import android.content.Context

class AndroidDashboardCache(context: Context) : DashboardCache {
    private val prefs = context.applicationContext
        .getSharedPreferences("financespy_dashboard_cache", Context.MODE_PRIVATE)

    override fun load(periodKey: String?): String? =
        prefs.getString(keyFor(periodKey), null)

    override fun save(periodKey: String?, json: String) {
        prefs.edit().putString(keyFor(periodKey), json).apply()
    }

    private fun keyFor(periodKey: String?) = "dashboard_${periodKey ?: "default"}"
}
