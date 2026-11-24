package py.com.cdco.financespy.wallet

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

// Separate toggle from the rest of Wallet capture: a user can want bank
// notification capture (amount/merchant/item) without also sharing device
// GPS location for it. Opt-in by default, EXCEPT if the user already granted
// background location permission directly in Android System Settings without
// having explicitly turned the in-app toggle off.
class WalletLocationPreferences(context: Context) {
    private val appContext = context.applicationContext
    private val prefs = appContext
        .getSharedPreferences("financespy_wallet_prefs", Context.MODE_PRIVATE)

    fun isLocationCaptureEnabled(): Boolean {
        if (prefs.contains(KEY_LOCATION_ENABLED)) {
            return prefs.getBoolean(KEY_LOCATION_ENABLED, false)
        }
        return hasSystemBackgroundLocationPermission(appContext)
    }

    fun setLocationCaptureEnabled(enabled: Boolean) {
        prefs.edit().putBoolean(KEY_LOCATION_ENABLED, enabled).apply()
    }

    companion object {
        private const val KEY_LOCATION_ENABLED = "location_capture_enabled"

        internal fun hasSystemBackgroundLocationPermission(context: Context): Boolean {
            val hasForeground = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACCESS_FINE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED ||
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
            if (!hasForeground) return false

            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.ACCESS_BACKGROUND_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
            } else {
                true
            }
        }
    }
}
