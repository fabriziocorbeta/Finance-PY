package py.com.cdco.financespy.auth

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class AndroidTokenStorage(context: Context) : TokenStorage {
    private val appContext = context.applicationContext
    private val prefs: SharedPreferences by lazy {
        EncryptedSharedPreferences.create(
            appContext,
            "financespy_auth_prefs",
            MasterKey.Builder(appContext).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    override suspend fun save(accessToken: String, refreshToken: String) = withContext(Dispatchers.IO) {
        prefs.edit().putString("access_token", accessToken).putString("refresh_token", refreshToken).apply()
    }

    override suspend fun accessToken(): String? = withContext(Dispatchers.IO) {
        prefs.getString("access_token", null)
    }

    override suspend fun refreshToken(): String? = withContext(Dispatchers.IO) {
        prefs.getString("refresh_token", null)
    }

    override suspend fun clear() = withContext(Dispatchers.IO) {
        prefs.edit().clear().apply()
    }
}
