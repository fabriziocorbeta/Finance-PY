package py.com.cdco.financespy.cache

import android.content.Context
import android.util.Base64
import androidx.security.crypto.EncryptedFile
import androidx.security.crypto.MasterKey
import py.com.cdco.financespy.security.EncryptedPrefsFactory
import py.com.cdco.financespy.security.OwnerScope
import py.com.cdco.financespy.sync.OfflineStore
import py.com.cdco.financespy.widgets.WidgetUpdater
import java.io.File

/**
 * Local persistence for the offline cache and the write queue.
 *
 * Each key lives in its own AES-256-GCM encrypted file under `filesDir/offline_store`.
 * It used to be one EncryptedSharedPreferences file, but SharedPreferences loads the
 * whole file into memory at startup and rewrites it on every change: with full copies
 * of sales, products, orders, chats and queued invoice photos that does not scale.
 *
 * Values written by older versions still live in the legacy prefs file; reads fall back
 * to it so a queued (not yet delivered) write is never lost on upgrade.
 */
class AndroidOfflineStore(
    context: Context,
    // Overridable for tests; defaults to the real device-wide owner marker.
    private val ownerId: () -> String? = { OwnerScope.currentOwnerId(context.applicationContext) }
) : OfflineStore {
    private val appContext = context.applicationContext
    private val legacyPrefs = EncryptedPrefsFactory.create(appContext, "financespy_offline_store")
    private val dir = File(appContext.filesDir, "offline_store").also { it.mkdirs() }
    private val masterKey by lazy {
        MasterKey.Builder(appContext).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build()
    }
    private val lock = Any()

    // In-memory only, to skip the owner check's SharedPreferences read/write
    // on every single get/put once we've already confirmed the owner for
    // this process lifetime.
    @Volatile private var lastCheckedOwner: String? = null

    override fun get(key: String): String? {
        ensureOwnerScope()
        val fromFile = synchronized(lock) { readFile(key) }
        return fromFile ?: legacyPrefs.getString(key, null)
    }

    override fun put(key: String, value: String) {
        ensureOwnerScope()
        synchronized(lock) { writeFile(key, value) }
        if (legacyPrefs.contains(key)) legacyPrefs.edit().remove(key).apply()
        if (key == "cache_market_tracker" || key == "cache_holdings_list" || key == "cache_accounts_list") {
            runCatching { WidgetUpdater.updateAll(appContext) }
        }
    }

    override fun remove(key: String) {
        synchronized(lock) { fileFor(key).delete() }
        if (legacyPrefs.contains(key)) legacyPrefs.edit().remove(key).apply()
    }

    /** Drops everything: the outbox queue and every cached reference list. */
    fun wipeAll() {
        synchronized(lock) { dir.listFiles()?.forEach { it.delete() } }
        legacyPrefs.edit().clear().apply()
        lastCheckedOwner = null
    }

    private fun fileFor(key: String): File {
        val name = Base64.encodeToString(
            key.toByteArray(Charsets.UTF_8),
            Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING
        )
        return File(dir, "$name.bin")
    }

    private fun encrypted(file: File) = EncryptedFile.Builder(
        appContext, file, masterKey, EncryptedFile.FileEncryptionScheme.AES256_GCM_HKDF_4KB
    ).build()

    private fun readFile(key: String): String? {
        val file = fileFor(key)
        if (!file.exists()) return null
        return runCatching {
            encrypted(file).openFileInput().use { it.readBytes().toString(Charsets.UTF_8) }
        }.getOrNull()
    }

    private fun writeFile(key: String, value: String) {
        val file = fileFor(key)
        // EncryptedFile refuses to overwrite: remove the previous version first.
        if (file.exists()) file.delete()
        encrypted(file).openFileOutput().use { it.write(value.toByteArray(Charsets.UTF_8)) }
    }

    private fun ensureOwnerScope() {
        val current = ownerId() ?: return // not logged in / unknown yet: leave data as-is
        if (current == lastCheckedOwner) return

        val stored = synchronized(lock) { readFile(OWNER_KEY) } ?: legacyPrefs.getString(OWNER_KEY, null)
        if (OwnershipGuard.shouldWipe(stored, current)) {
            synchronized(lock) { dir.listFiles()?.forEach { it.delete() } }
            legacyPrefs.edit().clear().apply()
            synchronized(lock) { writeFile(OWNER_KEY, current) }
        } else if (stored == null) {
            synchronized(lock) { writeFile(OWNER_KEY, current) }
        }
        lastCheckedOwner = current
    }

    private companion object {
        const val OWNER_KEY = "_owner_family_id"
    }
}
