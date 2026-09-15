package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.UpayImportResultDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity

data class UpayImportUiState(
    val availableAccounts: List<AccountEntity> = emptyList(),
    val selectedAccountId: String = "",
    val pickedFileName: String? = null,
    val pickedFileBytes: ByteArray? = null,
    val isUploading: Boolean = false,
    val result: UpayImportResultDto? = null,
    val error: String? = null
)

// El backend procesa la liquidación de forma asíncrona (ImportJob) cuando se
// sube con publish=true, así que la respuesta inicial de uploadUpayImport
// casi siempre viene con status "importing". Se hace un polling corto
// (fetchImport) para intentar mostrar el resultado final sin que el usuario
// tenga que salir y volver a entrar a la pantalla.
class UpayImportViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    private val accountDao: AccountDao
) {
    private val _state = MutableStateFlow(UpayImportUiState())
    val state: StateFlow<UpayImportUiState> = _state.asStateFlow()

    init {
        scope.launch {
            accountDao.observeAll().collect { accounts ->
                val current = _state.value
                val selected = current.selectedAccountId.ifBlank { accounts.firstOrNull()?.id.orEmpty() }
                _state.value = current.copy(availableAccounts = accounts, selectedAccountId = selected)
            }
        }
    }

    fun selectAccount(accountId: String) {
        _state.value = _state.value.copy(selectedAccountId = accountId)
    }

    fun onFilePicked(bytes: ByteArray, fileName: String) {
        _state.value = _state.value.copy(
            pickedFileBytes = bytes,
            pickedFileName = fileName,
            result = null,
            error = null
        )
    }

    fun upload() {
        val s = _state.value
        val bytes = s.pickedFileBytes
        val fileName = s.pickedFileName

        if (s.selectedAccountId.isBlank()) {
            _state.value = s.copy(error = "Seleccioná una cuenta")
            return
        }
        if (bytes == null || fileName == null) {
            _state.value = s.copy(error = "Seleccioná el archivo CSV de Upay")
            return
        }

        scope.launch {
            _state.value = _state.value.copy(isUploading = true, error = null, result = null)
            try {
                var result = api.uploadUpayImport(s.selectedAccountId, bytes, fileName)
                if (result.status == "importing") {
                    delay(2500)
                    result = runCatching { api.fetchImport(result.id) }.getOrDefault(result)
                }
                _state.value = _state.value.copy(isUploading = false, result = result)
            } catch (e: Exception) {
                _state.value = _state.value.copy(
                    isUploading = false,
                    error = e.message ?: "Error al subir la liquidación"
                )
            }
        }
    }

    fun dismissResult() {
        _state.value = _state.value.copy(result = null, error = null, pickedFileBytes = null, pickedFileName = null)
    }
}
