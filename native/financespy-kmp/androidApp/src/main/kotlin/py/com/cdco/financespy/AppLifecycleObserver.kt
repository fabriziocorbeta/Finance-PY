package py.com.cdco.financespy

import android.content.Context
import android.content.SharedPreferences
import android.os.SystemClock
import android.util.Log
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import py.com.cdco.financespy.auth.AuthRepository

class AppLifecycleObserver(
    private val context: Context,
    private val authRepository: AuthRepository,
    private val onLogoutCallback: () -> Unit
) : DefaultLifecycleObserver {

    companion object {
        private const val INACTIVITY_TIMEOUT_MS = 3 * 60 * 1000L // 3 minutes
        private const val TAG = "AppLifecycleObserver"
        private const val PREFS_NAME = "financespy_lifecycle_prefs"
        private const val KEY_LAST_INTERACTION = "last_interaction_time"
        private const val THROTTLE_MS = 5000L
    }

    private val prefs: SharedPreferences by lazy {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    }

    private var lastInteractionTime: Long
        get() = prefs.getLong(KEY_LAST_INTERACTION, System.currentTimeMillis())
        set(value) {
            prefs.edit().putLong(KEY_LAST_INTERACTION, value).apply()
        }

    private var memoryLastInteractionTime = System.currentTimeMillis()
    private var isAppInForeground = false
    private var inactivityJob: Job? = null

    private val scope = CoroutineScope(Dispatchers.Main)

    init {
        // Initialize memory clock with persistent clock if available, else persist now
        val persisted = prefs.getLong(KEY_LAST_INTERACTION, 0L)
        if (persisted == 0L) {
            val now = System.currentTimeMillis()
            lastInteractionTime = now
            memoryLastInteractionTime = now
        } else {
            memoryLastInteractionTime = persisted
        }
    }

    private fun startInactivityTimer() {
        inactivityJob?.cancel()
        inactivityJob = scope.launch {
            while (isActive) {
                delay(1000)
                if (isAppInForeground) {
                    val now = System.currentTimeMillis()
                    val timeSinceLastInteraction = now - memoryLastInteractionTime
                    if (timeSinceLastInteraction > INACTIVITY_TIMEOUT_MS) {
                        performLogout()
                        break
                    }
                }
            }
        }
    }

    private fun performLogout() {
        Log.d(TAG, "checkInactivity: timeout reached, logging out")
        inactivityJob?.cancel()
        scope.launch(Dispatchers.IO) {
            authRepository.logout()
            withContext(Dispatchers.Main) {
                onLogoutCallback()
            }
        }
    }

    /**
     * Updates the interaction time. Returns true if the user was just logged out due to inactivity.
     */
    fun updateInteractionTime(): Boolean {
        val now = System.currentTimeMillis()
        val timeSinceLastInteraction = now - memoryLastInteractionTime
        if (timeSinceLastInteraction > INACTIVITY_TIMEOUT_MS) {
            performLogout()
            return true
        }
        memoryLastInteractionTime = now
        if (now - prefs.getLong(KEY_LAST_INTERACTION, 0L) > THROTTLE_MS) {
            lastInteractionTime = now
        }
        return false
    }

    override fun onStart(owner: LifecycleOwner) {
        super.onStart(owner)
        isAppInForeground = true
        Log.d(TAG, "onStart: app entered foreground")

        // Check if timeout was reached while in background using persistent time
        val now = System.currentTimeMillis()
        val timeSinceLastInteraction = now - lastInteractionTime
        if (timeSinceLastInteraction > INACTIVITY_TIMEOUT_MS) {
            Log.d(TAG, "onStart: timeout reached while in background")
            performLogout()
        } else {
            // Restore memory time from persistent time in case process died
            memoryLastInteractionTime = lastInteractionTime
            startInactivityTimer()
        }
    }

    override fun onStop(owner: LifecycleOwner) {
        super.onStop(owner)
        isAppInForeground = false
        Log.d(TAG, "onStop: app entered background")
        // Force flush of latest interaction time before going to background
        lastInteractionTime = memoryLastInteractionTime
        inactivityJob?.cancel()
    }

    fun cleanUp() {
        scope.cancel()
    }
}
