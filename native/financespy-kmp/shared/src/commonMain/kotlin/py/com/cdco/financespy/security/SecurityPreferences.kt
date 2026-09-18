package py.com.cdco.financespy.security

// Preferencia de seguridad por-dispositivo (ej. bloqueo biométrico al abrir
// la app) -- opt-in, no se sincroniza con el backend, solo persiste local.
interface SecurityPreferences {
    fun isBiometricLockEnabled(): Boolean
    fun setBiometricLockEnabled(enabled: Boolean)

    // Blocks screenshots/screen recording and hides the app content from
    // the OS recents-apps thumbnail. Opt-OUT (defaults to true): unlike
    // biometric lock, this one shipped as an always-on, non-negotiable
    // flag first -- making it a toggle must not silently weaken the
    // default for existing users.
    fun isScreenCaptureBlockEnabled(): Boolean
    fun setScreenCaptureBlockEnabled(enabled: Boolean)
}
