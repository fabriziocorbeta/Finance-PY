package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.FamilyExportDto
import py.com.cdco.financespy.api.dto.UserDto
import py.com.cdco.financespy.auth.AuthRepository
import py.com.cdco.financespy.sync.OfflineOutbox

data class SettingsUiState(
    val isLoading: Boolean = false,
    val currentUser: UserDto? = null,
    val familyMembers: List<UserDto> = emptyList(),
    val familyName: String? = null,
    val businessModeEnabled: Boolean = false,
    val familyExports: List<FamilyExportDto> = emptyList(),
    val isCreatingExport: Boolean = false,
    val downloadingExportId: String? = null,
    val error: String? = null
)

class SettingsViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    private val authRepository: AuthRepository,
    // Nullable/optional so existing test call sites that don't care about
    // the pending-outbox warning keep compiling; MainActivity always passes
    // the real outbox.
    private val outbox: OfflineOutbox? = null
) {
    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()
    private var pollingJob: Job? = null

    /** How many offline-queued changes would be lost by logging out right now. */
    val pendingOutboxCount: StateFlow<Int> get() = outbox?.pendingCount ?: MutableStateFlow(0)

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
                        familyName = settings.name,
                        businessModeEnabled = settings.business_mode_enabled
                    )
                }
                if (settings.current_user?.role.equals("admin", ignoreCase = true)) {
                    loadFamilyExports()
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

    fun loadFamilyExports() {
        scope.launch {
            runCatching {
                api.fetchFamilyExports().data
            }.onSuccess { exports ->
                _uiState.update { it.copy(familyExports = exports) }
                checkAndStartPollingIfNeeded(exports)
            }
        }
    }

    fun createFamilyExport() {
        scope.launch {
            _uiState.update { it.copy(isCreatingExport = true, error = null) }
            runCatching {
                api.createFamilyExport()
            }.onSuccess { newExport ->
                _uiState.update { state ->
                    val updated = listOf(newExport) + state.familyExports.filter { it.id != newExport.id }
                    state.copy(isCreatingExport = false, familyExports = updated)
                }
                startPollingForExports()
            }.onFailure { err ->
                _uiState.update {
                    it.copy(
                        isCreatingExport = false,
                        error = err.message ?: "Error al crear copia de seguridad"
                    )
                }
            }
        }
    }

    fun downloadAndShareExport(
        export: FamilyExportDto,
        onShareFile: (ByteArray, String, String) -> Unit
    ) {
        scope.launch {
            _uiState.update { it.copy(downloadingExportId = export.id, error = null) }
            runCatching {
                api.downloadFamilyExport(export.id)
            }.onSuccess { bytes ->
                _uiState.update { it.copy(downloadingExportId = null) }
                val name = export.filename ?: "backup_${export.id.take(8)}.zip"
                onShareFile(bytes, name, "application/zip")
            }.onFailure { err ->
                _uiState.update {
                    it.copy(
                        downloadingExportId = null,
                        error = err.message ?: "Error al descargar copia de seguridad"
                    )
                }
            }
        }
    }

    private fun checkAndStartPollingIfNeeded(exports: List<FamilyExportDto>) {
        val hasPending = exports.any { it.status == "pending" || it.status == "processing" }
        if (hasPending && pollingJob == null) {
            startPollingForExports()
        } else if (!hasPending) {
            stopPolling()
        }
    }

    private fun startPollingForExports() {
        stopPolling()
        pollingJob = scope.launch {
            while (true) {
                delay(3000)
                runCatching {
                    api.fetchFamilyExports().data
                }.onSuccess { exports ->
                    _uiState.update { it.copy(familyExports = exports) }
                    if (!exports.any { it.status == "pending" || it.status == "processing" }) {
                        stopPolling()
                    }
                }.onFailure {
                    stopPolling()
                }
            }
        }
    }

    private fun stopPolling() {
        pollingJob?.cancel()
        pollingJob = null
    }

    fun logout(onLoggedOut: () -> Unit) {
        stopPolling()
        scope.launch {
            authRepository.logout()
            onLoggedOut()
        }
    }
}
