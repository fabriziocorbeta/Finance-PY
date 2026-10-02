package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.PdfImportResultDto
import py.com.cdco.financespy.api.dto.PdfImportRowDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity

enum class PdfImportStep { PICK, PROCESSING, REVIEW, DONE }

data class PdfStatementImportUiState(
    val availableAccounts: List<AccountEntity> = emptyList(),
    val selectedAccountId: String = "",
    val pickedFileName: String? = null,
    val pickedFileBytes: ByteArray? = null,
    val step: PdfImportStep = PdfImportStep.PICK,
    val isBusy: Boolean = false,
    val importId: String? = null,
    val rows: List<PdfImportRowDto> = emptyList(),
    val error: String? = null
)

// The AI extraction step (ProcessPdfJob on the backend) runs async and can
// take anywhere from a few seconds to over a minute depending on statement
// length -- this polls #fetchImport on a fixed interval rather than a single
// delayed re-check (UpayImportViewModel's pattern), since there's no fixed
// upper bound on how long it'll take.
class PdfStatementImportViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    private val accountDao: AccountDao
) {
    private val _state = MutableStateFlow(PdfStatementImportUiState())
    val state: StateFlow<PdfStatementImportUiState> = _state.asStateFlow()

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
        _state.value = _state.value.copy(pickedFileBytes = bytes, pickedFileName = fileName, error = null)
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
            _state.value = s.copy(error = "Seleccioná el PDF del extracto")
            return
        }

        scope.launch {
            _state.value = _state.value.copy(isBusy = true, error = null, step = PdfImportStep.PROCESSING)
            try {
                val created = api.uploadPdfStatement(s.selectedAccountId, bytes, fileName)
                _state.value = _state.value.copy(importId = created.id)
                pollUntilReviewable(created)
            } catch (e: Exception) {
                _state.value = _state.value.copy(
                    isBusy = false,
                    step = PdfImportStep.PICK,
                    error = e.message ?: "Error al subir el extracto"
                )
            }
        }
    }

    private suspend fun pollUntilReviewable(initial: PdfImportResultDto) {
        var result = initial
        var attempts = 0
        // ~2 minutes of polling before giving up and telling the user to
        // check back later -- a real statement with many pages can take a
        // while, but this screen shouldn't spin forever if something's stuck.
        while (attempts < 40 && (result.status == "importing" || result.status == "pending" && result.stats?.rows_count == 0)) {
            delay(3000)
            result = runCatching { api.fetchImport(result.id) }.getOrDefault(result)
            attempts++
        }

        when {
            result.status == "failed" -> _state.value = _state.value.copy(
                isBusy = false,
                step = PdfImportStep.PICK,
                error = result.error ?: "No se pudo procesar el extracto"
            )
            (result.stats?.rows_count ?: 0) > 0 -> {
                val rows = runCatching { api.fetchPdfImportRows(result.id) }.getOrDefault(emptyList())
                _state.value = _state.value.copy(isBusy = false, step = PdfImportStep.REVIEW, rows = rows)
            }
            else -> _state.value = _state.value.copy(
                isBusy = false,
                step = PdfImportStep.PICK,
                error = "El extracto se sigue procesando. Probá de nuevo en un rato desde Importaciones."
            )
        }
    }

    fun confirm() {
        val importId = _state.value.importId ?: return
        scope.launch {
            _state.value = _state.value.copy(isBusy = true, error = null)
            try {
                api.publishImport(importId)
                _state.value = _state.value.copy(isBusy = false, step = PdfImportStep.DONE)
            } catch (e: Exception) {
                _state.value = _state.value.copy(isBusy = false, error = e.message ?: "Error al confirmar la importación")
            }
        }
    }

    fun reset() {
        _state.value = PdfStatementImportUiState(
            availableAccounts = _state.value.availableAccounts,
            selectedAccountId = _state.value.selectedAccountId
        )
    }
}
