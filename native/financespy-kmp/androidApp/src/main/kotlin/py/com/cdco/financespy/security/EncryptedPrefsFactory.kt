package py.com.cdco.financespy.security

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Opens [fileName] as [EncryptedSharedPreferences] (AndroidX Security), with
 * the encryption key coming from the Android Keystore via [MasterKey] --
 * never hardcoded, same pattern already used by AndroidTokenStorage.
 *
 * If the file still holds String values written before this store switched
 * to encryption, those values are copied over once (so a queued offline
 * transaction or a cached list doesn't silently vanish on upgrade) and the
 * plaintext copies are then wiped from the file. Safe to call on a
 * brand-new file too: there's simply nothing to migrate.
 */
object EncryptedPrefsFactory {
    private const val MIGRATED_FLAG = "_encrypted_prefs_migrated"

    fun create(context: Context, fileName: String): SharedPreferences {
        val appContext = context.applicationContext
        val masterKey = MasterKey.Builder(appContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        val encrypted = EncryptedSharedPreferences.create(
            appContext,
            fileName,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
        migrateLegacyPlaintextIfNeeded(appContext, fileName, encrypted)
        return encrypted
    }

    private fun migrateLegacyPlaintextIfNeeded(
        context: Context,
        fileName: String,
        encrypted: SharedPreferences
    ) {
        if (encrypted.getBoolean(MIGRATED_FLAG, false)) return

        // Same underlying file: EncryptedSharedPreferences.create() above
        // does not touch pre-existing plaintext entries, it only encrypts
        // what it writes from here on. This plain view lets us read what
        // was written before encryption existed, under its original
        // (unencrypted) key names.
        val legacy = context.getSharedPreferences(fileName, Context.MODE_PRIVATE)
        val legacyStringEntries = legacy.all.filterValues { it is String }

        if (legacyStringEntries.isNotEmpty()) {
            val editor = encrypted.edit()
            legacyStringEntries.forEach { (key, value) -> editor.putString(key, value as String) }
            editor.apply()
            legacy.edit().clear().apply()
        }
        encrypted.edit().putBoolean(MIGRATED_FLAG, true).apply()
    }
}
