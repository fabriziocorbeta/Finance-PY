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

class AppLifecycleObserver(
    private val context: Context,
    private val onLockCallback: () -> Unit
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

    // The timeout must never apply before the user has ever logged in --
    // otherwise a login flow that takes long enough (or a process that's
    // simply been sitting on the login screen a while) races the OAuth
    // redirect: onStart()'s timeout check fires synchronously the instant
    // the app comes back from the browser, calls performLock() in a
    // coroutine, and that can land AFTER handleOAuthRedirect sets
    // isLoggedIn=true, silently flipping it back to false right after a
    // successful login. MainActivity keeps this in sync with isLoggedIn.
    var isLoggedIn: Boolean = false

    // While locked, touches on the lock screen must not re-trigger the lock
    // (they'd be swallowed) nor move the inactivity clock.
    private var isLocked = false

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
                if (isAppInForeground && isLoggedIn) {
                    val now = System.currentTimeMillis()
                    val timeSinceLastInteraction = now - memoryLastInteractionTime
                    if (timeSinceLastInteraction > INACTIVITY_TIMEOUT_MS) {
                        performLock()
                        break
                    }
                }
            }
        }
    }

    // Inactivity LOCKS the app, it never clears tokens. Wiping the refresh
    // token here meant a server outage + 3 idle minutes = no way back in
    // (login needs the server). Real logout stays an explicit user action.
    private fun performLock() {
        Log.d(TAG, "checkInactivity: timeout reached, locking")
        inactivityJob?.cancel()
        isLocked = true
        onLockCallback()
    }

    // Call once the user re-authenticated locally after a lock.
    fun onUnlocked() {
        isLocked = false
        resetClock()
        if (isAppInForeground && isLoggedIn) startInactivityTimer()
    }

    // Call after a successful (re-)login so a stale lastInteractionTime
    // (from sitting on the login screen a while, or a prior session) can't
    // immediately re-trigger a timeout the instant isLoggedIn flips true.
    fun resetClock() {
        isLocked = false
        val now = System.currentTimeMillis()
        memoryLastInteractionTime = now
        lastInteractionTime = now
    }

    /**
     * Updates the interaction time. Returns true if the user was just logged out due to inactivity.
     */
    fun updateInteractionTime(): Boolean {
        if (!isLoggedIn || isLocked) return false
        val now = System.currentTimeMillis()
        val timeSinceLastInteraction = now - memoryLastInteractionTime
        if (timeSinceLastInteraction > INACTIVITY_TIMEOUT_MS) {
            performLock()
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

        if (!isLoggedIn || isLocked) return

        // Check if timeout was reached while in background using persistent time
        val now = System.currentTimeMillis()
        val timeSinceLastInteraction = now - lastInteractionTime
        if (timeSinceLastInteraction > INACTIVITY_TIMEOUT_MS) {
            Log.d(TAG, "onStart: timeout reached while in background")
            performLock()
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
