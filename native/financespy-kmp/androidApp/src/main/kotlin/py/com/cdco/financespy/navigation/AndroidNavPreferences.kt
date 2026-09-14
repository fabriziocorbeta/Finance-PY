package py.com.cdco.financespy.navigation

import android.content.Context

class AndroidNavPreferences(context: Context) : NavPreferences {
    private val prefs = context.applicationContext
        .getSharedPreferences("financespy_nav_prefs", Context.MODE_PRIVATE)

    override fun loadOrder(): List<String>? {
        val raw = prefs.getString(KEY_ORDER, null) ?: return null
        return raw.split(",").filter { it.isNotBlank() }
    }

    override fun saveOrder(itemIds: List<String>) {
        prefs.edit().putString(KEY_ORDER, itemIds.joinToString(",")).apply()
    }

    companion object {
        private const val KEY_ORDER = "bottom_nav_item_order"
    }
}
