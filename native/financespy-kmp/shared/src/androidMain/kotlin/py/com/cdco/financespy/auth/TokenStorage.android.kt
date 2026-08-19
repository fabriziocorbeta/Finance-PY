package py.com.cdco.financespy.auth

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

class AndroidTokenStorage(context: Context) : TokenStorage {
    private val prefs: SharedPreferences = EncryptedSharedPreferences.create(
        context,
        "financespy_auth_prefs",
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    override suspend fun save(accessToken: String, refreshToken: String) {
        prefs.edit().putString("access_token", accessToken).putString("refresh_token", refreshToken).apply()
    }

    override suspend fun accessToken(): String? = prefs.getString("access_token", null)
    override suspend fun refreshToken(): String? = prefs.getString("refresh_token", null)
    override suspend fun clear() { prefs.edit().clear().apply() }
}
