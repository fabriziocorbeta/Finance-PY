package py.com.cdco.financespy

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
    private val authRepository: AuthRepository,
    private val onLogoutCallback: () -> Unit
) : DefaultLifecycleObserver {

    companion object {
        private const val INACTIVITY_TIMEOUT_MS = 3 * 60 * 1000L // 3 minutes
        private const val TAG = "AppLifecycleObserver"
    }

    private var lastInteractionTime = SystemClock.elapsedRealtime()
    private var isAppInForeground = false
    private var inactivityJob: Job? = null

    private val scope = CoroutineScope(Dispatchers.Main)

    private fun startInactivityTimer() {
        inactivityJob?.cancel()
        inactivityJob = scope.launch {
            while (isActive) {
                delay(1000)
                if (isAppInForeground) {
                    val now = SystemClock.elapsedRealtime()
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
        val now = SystemClock.elapsedRealtime()
        val timeSinceLastInteraction = now - lastInteractionTime
        if (timeSinceLastInteraction > INACTIVITY_TIMEOUT_MS) {
            performLogout()
            return true
        }
        lastInteractionTime = now
        return false
    }

    override fun onStart(owner: LifecycleOwner) {
        super.onStart(owner)
        isAppInForeground = true
        Log.d(TAG, "onStart: app entered foreground")

        // Check if timeout was reached while in background
        val now = SystemClock.elapsedRealtime()
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
    }

    fun cleanUp() {
        scope.cancel()
    }
}
