package py.com.cdco.financespy.security

import android.content.Context

class AndroidSecurityPreferences(context: Context) : SecurityPreferences {
    private val prefs = context.applicationContext
        .getSharedPreferences("financespy_security_prefs", Context.MODE_PRIVATE)

    override fun isBiometricLockEnabled(): Boolean = prefs.getBoolean(KEY_ENABLED, false)

    override fun setBiometricLockEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_ENABLED, enabled).apply()
    }

    override fun isScreenCaptureBlockEnabled(): Boolean = prefs.getBoolean(KEY_SCREEN_CAPTURE_BLOCK, true)

    override fun setScreenCaptureBlockEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_SCREEN_CAPTURE_BLOCK, enabled).apply()
    }

    companion object {
        private const val KEY_ENABLED = "biometric_lock_enabled"
        private const val KEY_SCREEN_CAPTURE_BLOCK = "screen_capture_block_enabled"
    }
}
