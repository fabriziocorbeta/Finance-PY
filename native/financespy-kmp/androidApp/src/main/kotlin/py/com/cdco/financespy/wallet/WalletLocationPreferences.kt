package py.com.cdco.financespy.wallet

import android.content.Context

// Separate toggle from the rest of Wallet capture: a user can want bank
// notification capture (amount/merchant/item) without also sharing device
// GPS location for it. Disabled by default -- this is opt-in, not opt-out.
class WalletLocationPreferences(context: Context) {
    private val prefs = context.applicationContext
        .getSharedPreferences("financespy_wallet_prefs", Context.MODE_PRIVATE)

    fun isLocationCaptureEnabled(): Boolean = prefs.getBoolean(KEY_LOCATION_ENABLED, false)

    fun setLocationCaptureEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_LOCATION_ENABLED, enabled).apply()
    }

    companion object {
        private const val KEY_LOCATION_ENABLED = "location_capture_enabled"
    }
}
