package py.com.cdco.financespy

import android.content.Context
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

// Uses wall-clock time (System.currentTimeMillis), persisted to
// SharedPreferences, instead of an in-memory SystemClock.elapsedRealtime.
// The in-memory version was reset to "now" every time this observer was
// reconstructed -- on process death (the OS routinely kills backgrounded
// apps) or on Activity/config-change recreation (rotation) -- which
// silently defeated the whole timeout: swipe the app away and reopen it
// after hours, and the clock restarted as if the user had just touched it.
class AppLifecycleObserver(
    context: Context,
    private val authRepository: AuthRepository,
    private val onLogoutCallback: () -> Unit
) : DefaultLifecycleObserver {

    companion object {
        private const val INACTIVITY_TIMEOUT_MS = 3 * 60 * 1000L // 3 minutes
        private const val PERSIST_THROTTLE_MS = 5 * 1000L // avoid a prefs write per touch event
        private const val PREFS_NAME = "financespy_inactivity_prefs"
        private const val KEY_LAST_INTERACTION = "last_interaction_wall_clock_ms"
        private const val TAG = "AppLifecycleObserver"
    }

    private val prefs = context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private var lastInteractionTime = prefs.getLong(KEY_LAST_INTERACTION, System.currentTimeMillis())
    private var lastPersistedTime = lastInteractionTime
    private var isAppInForeground = false
    private var inactivityJob: Job? = null

    private val scope = CoroutineScope(Dispatchers.Main)

    private fun persist(now: Long) {
        lastPersistedTime = now
        prefs.edit().putLong(KEY_LAST_INTERACTION, now).apply()
    }

    private fun startInactivityTimer() {
        inactivityJob?.cancel()
        inactivityJob = scope.launch {
            while (isActive) {
                delay(1000)
                if (isAppInForeground) {
                    val now = System.currentTimeMillis()
                    val timeSinceLastInteraction = now - lastInteractionTime
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
        prefs.edit().remove(KEY_LAST_INTERACTION).apply()
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
        val timeSinceLastInteraction = now - lastInteractionTime
        if (timeSinceLastInteraction > INACTIVITY_TIMEOUT_MS) {
            performLogout()
            return true
        }
        lastInteractionTime = now
        if (now - lastPersistedTime >= PERSIST_THROTTLE_MS) {
            persist(now)
        }
        return false
    }

    override fun onStart(owner: LifecycleOwner) {
        super.onStart(owner)
        isAppInForeground = true
        Log.d(TAG, "onStart: app entered foreground")

        // Check if timeout was reached while in background (or while the
        // process was dead, or across a rotation) -- lastInteractionTime
        // came from persisted storage, not a freshly-reset in-memory field.
        val now = System.currentTimeMillis()
        val timeSinceLastInteraction = now - lastInteractionTime
        if (timeSinceLastInteraction > INACTIVITY_TIMEOUT_MS) {
            Log.d(TAG, "onStart: timeout reached while in background")
            performLogout()
        } else {
            startInactivityTimer()
        }
    }

    override fun onStop(owner: LifecycleOwner) {
        super.onStop(owner)
        isAppInForeground = false
        Log.d(TAG, "onStop: app entered background")
        inactivityJob?.cancel()
        persist(lastInteractionTime)
    }

    fun cleanUp() {
        scope.cancel()
    }
}
