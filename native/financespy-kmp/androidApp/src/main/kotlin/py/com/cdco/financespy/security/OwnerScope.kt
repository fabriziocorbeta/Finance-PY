package py.com.cdco.financespy.security

import android.content.Context

/**
 * Tracks whose data (which family) is currently on this device, so the
 * offline outbox / dashboard cache / Wallet pending captures can tell
 * "my data" from "the previous user's data" and never show the latter to
 * someone else.
 *
 * Backed by its own tiny EncryptedSharedPreferences file -- deliberately
 * separate from the auth token store, so clearing tokens on logout doesn't
 * implicitly clear this, and vice versa; the two are cleared explicitly and
 * at different points (owner is cleared as part of wipeLocalData()).
 */
object OwnerScope {
    private const val FILE = "financespy_owner_scope"
    private const val KEY_OWNER_ID = "current_owner_family_id"

    fun currentOwnerId(context: Context): String? =
        EncryptedPrefsFactory.create(context.applicationContext, FILE).getString(KEY_OWNER_ID, null)

    fun setCurrentOwnerId(context: Context, ownerId: String) {
        EncryptedPrefsFactory.create(context.applicationContext, FILE)
            .edit().putString(KEY_OWNER_ID, ownerId).apply()
    }

    fun clear(context: Context) {
        EncryptedPrefsFactory.create(context.applicationContext, FILE).edit().clear().apply()
    }
}
