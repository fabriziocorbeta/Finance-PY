package py.com.cdco.financespy.wallet

import android.content.Context
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.runBlocking
import py.com.cdco.financespy.db.buildDatabase
import py.com.cdco.financespy.db.initDatabaseBuilder

object AccountMapping {
    fun accountIdFor(context: Context, cardText: String): String? {
        initDatabaseBuilder(context)
        val db = buildDatabase()

        val accounts = runBlocking {
            db.accountDao().observeAll().firstOrNull()
        } ?: return null

        return accounts.firstOrNull { account ->
            cardText.contains(account.name, ignoreCase = true) || account.name.contains(cardText, ignoreCase = true)
        }?.id
    }
}
