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

    // EncryptedSharedPreferences.create() above persists its own Tink keyset
    // into this SAME physical file as two plain String entries before this
    // migration ever runs. The raw/legacy view below shares that file, so
    // without this exclusion the keyset is misread as "legacy plaintext to
    // migrate" and rewriting it through the encrypted editor throws
    // (EncryptedSharedPreferences.Editor rejects these exact key names with
    // a SecurityException) -- crashing on every brand-new file, i.e. every
    // first-ever launch for a new user. Names are from the library's own
    // internal MasterKeys/EncryptedSharedPreferences implementation.
    private val RESERVED_KEYSET_KEYS = setOf(
        "__androidx_security_crypto_encrypted_prefs_key_keyset__",
        "__androidx_security_crypto_encrypted_prefs_value_keyset__"
    )

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
        val legacyStringEntries = legacy.all
            .filterValues { it is String }
            .filterKeys { it !in RESERVED_KEYSET_KEYS }

        if (legacyStringEntries.isNotEmpty()) {
            val editor = encrypted.edit()
            legacyStringEntries.forEach { (key, value) -> editor.putString(key, value as String) }
            editor.apply()
            // Remove only the keys we just migrated -- `legacy` and
            // `encrypted` are views over the SAME file, so a blanket
            // clear() here would also delete the keyset entries that make
            // `encrypted` readable at all.
            val legacyEditor = legacy.edit()
            legacyStringEntries.keys.forEach { legacyEditor.remove(it) }
            legacyEditor.apply()
        }
        encrypted.edit().putBoolean(MIGRATED_FLAG, true).apply()
    }
}
