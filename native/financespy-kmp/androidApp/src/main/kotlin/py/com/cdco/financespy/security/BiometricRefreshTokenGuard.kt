package py.com.cdco.financespy.security

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.util.Base64
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Ties the refresh token to a biometric-authenticated Keystore key, SOLO
 * while the user has the biometric-lock toggle on (AndroidSecurityPreferences
 * / SecurityPreferences.isBiometricLockEnabled). With the toggle off this
 * class is never touched and nothing changes vs. before: the refresh token
 * keeps living in AndroidTokenStorage's own EncryptedSharedPreferences
 * (Keystore-backed MasterKey, no biometric gate), same as every other stored
 * value.
 *
 * With the toggle on, a SECOND copy of the refresh token is additionally
 * wrapped with a key that requires a fresh biometric (or device-credential)
 * check for every single use (setUserAuthenticationRequired(true), no
 * validity window) -- so unlocking the app isn't just a UI gate in front of
 * data that was reachable anyway, the token itself needs the user present.
 * The plaintext copy in AndroidTokenStorage still exists (defense in depth,
 * not defense-in-*only*-depth): this app has to keep working with the
 * server unreachable / during an inactivity-timeout lock, per product
 * decision (see AppLifecycleObserver / MainActivity comments -- inactivity
 * lock must NOT wipe tokens), so the wrapped copy is a verification gate at
 * unlock time, not the sole custodian of the token.
 *
 * setInvalidatedByBiometricEnrollment(true): if the user adds/removes a
 * fingerprint or face after enabling the toggle, the key is permanently
 * invalidated by the OS. That must never crash and must never trap the user
 * -- callers catch KeyPermanentlyInvalidatedException, call
 * [reset], and fall back to asking for a normal re-login (see MainActivity).
 */
object BiometricRefreshTokenGuard {
    private const val KEY_ALIAS = "financespy_refresh_token_biometric_key"
    private const val ANDROID_KEYSTORE = "AndroidKeyStore"
    private const val TRANSFORMATION =
        "${KeyProperties.KEY_ALGORITHM_AES}/${KeyProperties.BLOCK_MODE_GCM}/${KeyProperties.ENCRYPTION_PADDING_NONE}"
    private const val GCM_TAG_LENGTH_BITS = 128

    private const val PREFS_FILE = "financespy_biometric_refresh"
    private const val KEY_WRAPPED_TOKEN = "wrapped_refresh_token"
    private const val KEY_IV = "wrapped_refresh_token_iv"

    /** Thrown by [decryptCipher] when the Keystore key is gone -- enrollment
     * changed, or nothing was ever wrapped. Callers must treat this as "ask
     * the user to log in again", never as a crash. */
    class GuardInvalidatedException(cause: Throwable? = null) : Exception(cause)

    private fun keyStore(): KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    private fun getOrCreateSecretKey(): SecretKey {
        val ks = keyStore()
        (ks.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }

        val keyGenerator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        val specBuilder = KeyGenParameterSpec.Builder(
            KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            specBuilder.setUserAuthenticationParameters(
                0,
                KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL
            )
        } else {
            @Suppress("DEPRECATION")
            specBuilder.setUserAuthenticationValidityDurationSeconds(-1)
        }

        keyGenerator.init(specBuilder.build())
        return keyGenerator.generateKey()
    }

    /** Cipher for wrapping the refresh token. Caller must run the returned
     * cipher through a BiometricPrompt CryptoObject before using it --
     * PURPOSE_ENCRYPT still requires the per-use auth check with the spec
     * above, same as decrypt. */
    fun encryptCipher(): Cipher {
        val cipher = Cipher.getInstance(TRANSFORMATION)
        try {
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateSecretKey())
        } catch (e: KeyPermanentlyInvalidatedException) {
            throw GuardInvalidatedException(e)
        }
        return cipher
    }

    /** Cipher for unwrapping the stored refresh token. Returns null when
     * nothing is wrapped (toggle was never turned on, or [clear] ran). */
    fun decryptCipher(context: Context): Cipher? {
        val iv = readIv(context) ?: return null
        val cipher = Cipher.getInstance(TRANSFORMATION)
        try {
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateSecretKey(), GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv))
        } catch (e: KeyPermanentlyInvalidatedException) {
            throw GuardInvalidatedException(e)
        }
        return cipher
    }

    fun hasWrappedToken(context: Context): Boolean = readWrapped(context) != null

    /** Encrypts [refreshToken] with an already-authenticated (post-BiometricPrompt)
     * [cipher] and persists the ciphertext + IV. Call only from the
     * BiometricPrompt success callback for an ENCRYPT-mode CryptoObject. */
    fun storeWrapped(context: Context, cipher: Cipher, refreshToken: String) {
        val ciphertext = cipher.doFinal(refreshToken.toByteArray(Charsets.UTF_8))
        val prefs = EncryptedPrefsFactory.create(context.applicationContext, PREFS_FILE)
        prefs.edit()
            .putString(KEY_WRAPPED_TOKEN, Base64.encodeToString(ciphertext, Base64.NO_WRAP))
            .putString(KEY_IV, Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
            .apply()
    }

    /** Decrypts the stored refresh token with an already-authenticated
     * (post-BiometricPrompt) [cipher]. Returns null if nothing was wrapped. */
    fun unwrap(context: Context, cipher: Cipher): String? {
        val (ciphertext, _) = readWrapped(context) ?: return null
        return String(cipher.doFinal(ciphertext), Charsets.UTF_8)
    }

    fun clear(context: Context) {
        EncryptedPrefsFactory.create(context.applicationContext, PREFS_FILE).edit().clear().apply()
    }

    /** Deletes the (now permanently-invalidated or otherwise broken) Keystore
     * key and any wrapped ciphertext, so the next enable attempt starts
     * clean. Never throws -- called from error-recovery paths. */
    fun reset(context: Context) {
        runCatching { keyStore().deleteEntry(KEY_ALIAS) }
        clear(context)
    }

    private fun readIv(context: Context): ByteArray? = readWrapped(context)?.second

    private fun readWrapped(context: Context): Pair<ByteArray, ByteArray>? {
        val prefs = EncryptedPrefsFactory.create(context.applicationContext, PREFS_FILE)
        val wrappedB64 = prefs.getString(KEY_WRAPPED_TOKEN, null) ?: return null
        val ivB64 = prefs.getString(KEY_IV, null) ?: return null
        return Base64.decode(wrappedB64, Base64.NO_WRAP) to Base64.decode(ivB64, Base64.NO_WRAP)
    }
}
