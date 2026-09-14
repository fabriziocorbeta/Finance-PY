package py.com.cdco.financespy.navigation

// Preferencia de UI por-dispositivo (qué ítems van fijos en la barra inferior y
// en qué orden) -- no se sincroniza con el backend ni entre dispositivos, solo
// persiste localmente. Feature nueva, exclusiva de la app nativa, sin equivalente
// en la web.
interface NavPreferences {
    fun loadOrder(): List<String>?
    fun saveOrder(itemIds: List<String>)
}
