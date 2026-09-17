package py.com.cdco.financespy.security

// Preferencia de seguridad por-dispositivo (ej. bloqueo biométrico al abrir
// la app) -- opt-in, no se sincroniza con el backend, solo persiste local.
interface SecurityPreferences {
    fun isBiometricLockEnabled(): Boolean
    fun setBiometricLockEnabled(enabled: Boolean)
}
