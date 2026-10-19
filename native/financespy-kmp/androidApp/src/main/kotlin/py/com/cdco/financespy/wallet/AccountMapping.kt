package py.com.cdco.financespy.wallet

import android.content.Context
import kotlinx.coroutines.flow.firstOrNull
import kotlinx.coroutines.runBlocking
import py.com.cdco.financespy.db.buildDatabase
import py.com.cdco.financespy.db.initDatabaseBuilder

object AccountMapping {
    // Devuelve null tanto cuando no hay candidata como cuando hay varias: en
    // ambos casos WalletCaptureHandler encola la captura y la reintenta, que es
    // preferible a cargarla en la cuenta equivocada. Adivinar costó una compra
    // mal asignada el 2026-10-10 (ver CardTextMatcher).
    fun accountIdFor(context: Context, cardText: String): String? {
        initDatabaseBuilder(context)
        val db = buildDatabase()

        val accounts = runBlocking {
            db.accountDao().observeAll().firstOrNull()
        } ?: return null

        val candidates = accounts.map {
            CardTextMatcher.Candidate(
                id = it.id,
                name = it.name,
                cardIdentifier = it.cardIdentifier,
                institutionName = it.institutionName,
                accountType = it.accountType
            )
        }

        return when (val result = CardTextMatcher.match(cardText, candidates)) {
            is CardTextMatcher.Result.Matched -> result.accountId
            is CardTextMatcher.Result.Ambiguous -> null
            CardTextMatcher.Result.None -> null
        }
    }
}
