package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.UserDto
import py.com.cdco.financespy.auth.AuthRepository

data class SettingsUiState(
    val isLoading: Boolean = false,
    val currentUser: UserDto? = null,
    val familyMembers: List<UserDto> = emptyList(),
    val familyName: String? = null,
    val error: String? = null
)

class SettingsViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    private val authRepository: AuthRepository
) {
    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        loadSettings()
    }

    fun loadSettings() {
        scope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }
            runCatching {
                api.fetchFamilySettings()
            }.onSuccess { settings ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        currentUser = settings.current_user,
                        familyMembers = settings.users,
                        familyName = settings.name
                    )
                }
            }.onFailure { err ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = err.message ?: "Error al cargar la configuración"
                    )
                }
            }
        }
    }

    fun logout(onLoggedOut: () -> Unit) {
        scope.launch {
            authRepository.logout()
            onLoggedOut()
        }
    }
}
