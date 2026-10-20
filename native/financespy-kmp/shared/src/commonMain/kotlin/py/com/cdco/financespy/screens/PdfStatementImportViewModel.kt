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
        var waited = 0L
        // The old budget was ~2 minutes, which is less than the job actually
        // takes: a real 4-page credit-card statement measured 173s end to end
        // in production (7 chunks, 24 transactions). The screen gave up at
        // 120s and told the user to come back later while the extraction was
        // still running and about to succeed -- the rows were always there a
        // minute after the message appeared.
        //
        // Six minutes covers that with headroom. Polling backs off from 2s to
        // 5s so a slow statement doesn't mean a hundred requests.
        while (waited < POLL_BUDGET_MS &&
            (result.status == "importing" || result.status == "pending" && result.stats?.rows_count == 0)
        ) {
            val interval = if (waited < 30_000L) 2_000L else 5_000L
            delay(interval)
            waited += interval
            result = runCatching { api.fetchImport(result.id) }.getOrDefault(result)
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
            // Genuinely still running after the full budget. The work is not
            // lost -- the job keeps going and the rows land in Importaciones --
            // so the message says where to find them rather than implying the
            // upload failed.
            else -> _state.value = _state.value.copy(
                isBusy = false,
                step = PdfImportStep.PICK,
                error = "El extracto sigue procesándose en el servidor. " +
                    "Las transacciones van a aparecer en Importaciones cuando termine; no hace falta volver a subirlo."
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

    private companion object {
        // Measured: a 4-page credit-card statement took 173s end to end in
        // production. 6 minutes leaves room for a longer one without the
        // screen claiming failure while the job is still working.
        const val POLL_BUDGET_MS = 360_000L
    }

}
