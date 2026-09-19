package py.com.cdco.financespy.cache

import android.content.Context
import py.com.cdco.financespy.sync.OfflineStore

class AndroidOfflineStore(context: Context) : OfflineStore {
    private val prefs = context.applicationContext
        .getSharedPreferences("financespy_offline_store", Context.MODE_PRIVATE)

    override fun get(key: String): String? = prefs.getString(key, null)

    override fun put(key: String, value: String) {
        prefs.edit().putString(key, value).apply()
    }
}
