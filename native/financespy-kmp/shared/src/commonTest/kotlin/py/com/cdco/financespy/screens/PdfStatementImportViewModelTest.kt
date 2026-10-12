package py.com.cdco.financespy.screens

import io.ktor.client.HttpClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.PdfImportResultDto
import py.com.cdco.financespy.api.dto.PdfImportRowDto
import py.com.cdco.financespy.api.dto.PdfImportRowFieldsDto
import py.com.cdco.financespy.api.dto.UpayImportStatsDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals

class PdfImportFakeApi : FinancePyApi(HttpClient()) {
    var shouldFailUpload = false
    var shouldFailConfirm = false
    var pollCount = 0
    var publishedId: String? = null

    override suspend fun uploadPdfStatement(accountId: String, fileBytes: ByteArray, fileName: String): PdfImportResultDto {
        if (shouldFailUpload) throw Exception("Upload failed")
        return PdfImportResultDto(id = "import_1", status = "importing", type = "pdf", error = null, stats = UpayImportStatsDto(0, 0, 0))
    }

    override suspend fun fetchImport(importId: String): PdfImportResultDto {
        pollCount++
        if (pollCount < 2) {
            return PdfImportResultDto(id = importId, status = "importing", type = "pdf", error = null, stats = UpayImportStatsDto(0, 0, 0))
        }
        return PdfImportResultDto(id = importId, status = "pending", type = "pdf", error = null, stats = UpayImportStatsDto(2, 2, 0))
    }

    override suspend fun fetchPdfImportRows(importId: String): List<PdfImportRowDto> {
        return listOf(
            PdfImportRowDto(id = "r1", row_number = 1, valid = true, fields = PdfImportRowFieldsDto(date = "2025-01-01", amount = "100.0", name = "Test 1")),
            PdfImportRowDto(id = "r2", row_number = 2, valid = true, fields = PdfImportRowFieldsDto(date = "2025-01-02", amount = "-50.0", name = "Test 2"))
        )
    }

    override suspend fun publishImport(importId: String): PdfImportResultDto {
        if (shouldFailConfirm) throw Exception("Publish failed")
        publishedId = importId
        return PdfImportResultDto(id = importId, status = "published", type = "pdf", error = null, stats = UpayImportStatsDto(2, 2, 0))
    }
}

class PdfFakeAccountDao : AccountDao {
    override fun observeAll(): Flow<List<AccountEntity>> = flowOf(listOf(
        AccountEntity(id = "acc1", name = "Test Account", balanceCents = 0, cashBalanceCents = 0, currency = "USD", classification = "asset", accountType = "depository", subtype = "checking", status = "active", updatedAt = "2025-01-01")
    ))
    override suspend fun upsertAll(accounts: List<AccountEntity>) {}
    override suspend fun deleteAllExcept(ids: List<String>) {}
}

@OptIn(ExperimentalCoroutinesApi::class)
class PdfStatementImportViewModelTest {
    private val testDispatcher = StandardTestDispatcher()
    private val testScope = TestScope(testDispatcher)
    private val fakeApi = PdfImportFakeApi()
    private val fakeDao = PdfFakeAccountDao()

    @BeforeTest
    fun setUp() {
        Dispatchers.setMain(testDispatcher)
        fakeApi.shouldFailUpload = false
        fakeApi.shouldFailConfirm = false
        fakeApi.pollCount = 0
        fakeApi.publishedId = null
    }

    @AfterTest
    fun tearDown() {
        Dispatchers.resetMain()
    }

    @Test
    fun testInitialState() = runTest {
        val viewModel = PdfStatementImportViewModel(this, fakeApi, fakeDao)
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.state.value
        assertEquals("acc1", state.selectedAccountId)
        assertEquals(1, state.availableAccounts.size)
        assertEquals(PdfImportStep.PICK, state.step)
    }

    @Test
    fun testUploadSuccessAndPoll() = runTest {
        val viewModel = PdfStatementImportViewModel(this, fakeApi, fakeDao)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.onFilePicked(byteArrayOf(1, 2, 3), "test.pdf")
        viewModel.upload()

        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.state.value
        assertEquals(PdfImportStep.REVIEW, state.step)
        assertEquals(2, state.rows.size)
        assertEquals("import_1", state.importId)
    }

    @Test
    fun testUploadError() = runTest {
        fakeApi.shouldFailUpload = true
        val viewModel = PdfStatementImportViewModel(this, fakeApi, fakeDao)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.onFilePicked(byteArrayOf(1, 2, 3), "test.pdf")
        viewModel.upload()

        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.state.value
        assertEquals(PdfImportStep.PICK, state.step)
        assertEquals("Upload failed", state.error)
    }

    @Test
    fun testConfirmSuccess() = runTest {
        val viewModel = PdfStatementImportViewModel(this, fakeApi, fakeDao)
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.onFilePicked(byteArrayOf(1, 2, 3), "test.pdf")
        viewModel.upload()
        testDispatcher.scheduler.advanceUntilIdle()

        viewModel.confirm()
        testDispatcher.scheduler.advanceUntilIdle()

        val state = viewModel.state.value
        assertEquals(PdfImportStep.DONE, state.step)
        assertEquals("import_1", fakeApi.publishedId)
    }
}
