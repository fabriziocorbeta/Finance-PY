package py.com.cdco.financespy.auth

import kotlinx.coroutines.sync.Mutex

/**
 * Shared mutex serializing OAuth refresh-token rotations across both Ktor's
 * BearerAuthProvider (ApiClient) and background Android webhook captures
 * (WalletCaptureHandler), preventing concurrent rotation from revoking a
 * refresh token still in flight.
 */
object TokenRefreshLock {
    val mutex: Mutex = Mutex()
}
