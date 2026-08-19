package py.com.cdco.financespy.auth

interface TokenStorage {
    suspend fun save(accessToken: String, refreshToken: String)
    suspend fun accessToken(): String?
    suspend fun refreshToken(): String?
    suspend fun clear()
}
