package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.CategoryDto
import py.com.cdco.financespy.api.dto.MerchantDto
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.api.dto.TransactionsResponse
import py.com.cdco.financespy.api.dto.AccountRefDto
import py.com.cdco.financespy.api.dto.CategoryRefDto
import py.com.cdco.financespy.api.dto.MerchantRefDto
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.EntryDao
import py.com.cdco.financespy.db.TransactionDao
import py.com.cdco.financespy.sync.OfflineOutbox
import py.com.cdco.financespy.sync.amountTextToCents
import kotlin.math.abs

private const val PENDING_PREFIX = "pending:"
private const val PAGE_SIZE = 25
private const val SEARCH_DEBOUNCE_MS = 400L

data class TransactionsUiState(
    val transactions: List<TransactionListItemDto> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val error: String? = null,
    val searchQuery: String = "",
    val selectedAccountId: String? = null,
    val selectedCategoryId: String? = null,
    val selectedType: String = "all", // "all" | "income" | "expense"
    val startDate: String? = null,
    val endDate: String? = null,
    val categories: List<CategoryDto> = emptyList(),
    val merchants: List<MerchantDto> = emptyList(),
    val accounts: List<AccountDto> = emptyList(),
    val currentPage: Int = 1,
    val hasMorePages: Boolean = false,
    // Showing the local 90-day copy because the server did not answer.
    val isOffline: Boolean = false
)

class TransactionsViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    private val entryDao: EntryDao? = null,
    private val transactionDao: TransactionDao? = null,
    private val accountDao: AccountDao? = null,
    private val outbox: OfflineOutbox? = null
) {
    private val _uiState = MutableStateFlow(TransactionsUiState())
    val uiState: StateFlow<TransactionsUiState> = _uiState.asStateFlow()

    private var searchJob: Job? = null

    init {
        scope.launch {
            val categories = try { api.fetchCategories() } catch (_: Exception) { emptyList() }
            val merchants = try { api.fetchMerchants() } catch (_: Exception) { emptyList() }
            val accounts = try { api.fetchAllAccounts() } catch (_: Exception) { emptyList() }
            _uiState.value = _uiState.value.copy(
                categories = categories,
                merchants = merchants,
                accounts = accounts
            )
        }
        loadTransactions()
    }

    private suspend fun fetchPage(page: Int): TransactionsResponse {
        val state = _uiState.value
        return api.fetchTransactionsPage(
            page = page,
            perPage = PAGE_SIZE,
            startDate = state.startDate,
            endDate = state.endDate,
            categoryId = state.selectedCategoryId,
            search = state.searchQuery.ifBlank { null },
            accountId = state.selectedAccountId,
            type = state.selectedType.takeIf { it != "all" }
        )
    }

    // NOTE: fetchTransactionsPage() is defined on FinancePyApi (single-page, no auto-pagination) -
    // added there since FinancePyApi.http is private and not reachable from an extension here.

    fun loadTransactions(resetPage: Boolean = true) {
        scope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            try {
                val page = if (resetPage) 1 else _uiState.value.currentPage
                val response = fetchPage(page)
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    transactions = (if (page == 1) pendingRows() else emptyList()) + response.transactions,
                    currentPage = page,
                    hasMorePages = page < response.pagination.total_pages,
                    isOffline = false
                )
            } catch (e: Exception) {
                val local = if (resetPage) loadOffline() else null
                _uiState.value = if (local != null) {
                    _uiState.value.copy(
                        isLoading = false, error = null, transactions = local,
                        currentPage = 1, hasMorePages = false, isOffline = true
                    )
                } else {
                    _uiState.value.copy(
                        isLoading = false,
                        error = e.message ?: "Error al cargar las transacciones"
                    )
                }
            }
        }
    }

    fun loadMore() {
        val state = _uiState.value
        if (state.isLoadingMore || state.isLoading || !state.hasMorePages) return

        scope.launch {
            _uiState.value = _uiState.value.copy(isLoadingMore = true, error = null)
            try {
                val nextPage = state.currentPage + 1
                val response = fetchPage(nextPage)
                _uiState.value = _uiState.value.copy(
                    isLoadingMore = false,
                    transactions = _uiState.value.transactions + response.transactions,
                    currentPage = nextPage,
                    hasMorePages = nextPage < response.pagination.total_pages
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoadingMore = false,
                    error = e.message ?: "Error al cargar más transacciones"
                )
            }
        }
    }

    fun updateSearchQuery(query: String) {
        _uiState.value = _uiState.value.copy(searchQuery = query)
        searchJob?.cancel()
        searchJob = scope.launch {
            delay(SEARCH_DEBOUNCE_MS)
            if (isActive) {
                loadTransactions(resetPage = true)
            }
        }
    }

    fun applyFilters(
        accountId: String?,
        categoryId: String?,
        type: String,
        startDate: String?,
        endDate: String?
    ) {
        _uiState.value = _uiState.value.copy(
            selectedAccountId = accountId,
            selectedCategoryId = categoryId,
            selectedType = type,
            startDate = startDate,
            endDate = endDate
        )
        loadTransactions(resetPage = true)
    }

    fun clearFilters() {
        _uiState.value = _uiState.value.copy(
            selectedAccountId = null,
            selectedCategoryId = null,
            selectedType = "all",
            startDate = null,
            endDate = null
        )
        loadTransactions(resetPage = true)
    }

    fun deleteTransaction(id: String, onDone: () -> Unit) {
        scope.launch {
            try {
                if (id.startsWith(PENDING_PREFIX)) {
                    outbox?.discard(id.removePrefix(PENDING_PREFIX))
                    loadTransactions(resetPage = true)
                    return@launch
                }
                try {
                    api.deleteTransaction(id)
                    loadTransactions(resetPage = true)
                } catch (e: Exception) {
                    val row = _uiState.value.transactions.firstOrNull { it.id == id }
                    if (outbox != null && outbox.shouldQueue(e)) {
                        outbox.enqueueTransactionDelete(id, "Eliminar: ${row?.name ?: id}")
                        _uiState.value = _uiState.value.copy(
                            transactions = _uiState.value.transactions.filter { it.id != id }
                        )
                    } else {
                        _uiState.value = _uiState.value.copy(error = e.message ?: "Error al eliminar la transacción")
                    }
                }
            } finally {
                onDone()
            }
        }
    }

    // Creates still in the outbox, shown on top marked "pending".
    private suspend fun pendingRows(): List<TransactionListItemDto> {
        val ob = outbox ?: return emptyList()
        val accounts = accountDao?.observeAll()?.first().orEmpty().associateBy { it.id }
        return ob.pendingItems.value.filter { !it.failed }.mapNotNull { item ->
            val b = ob.decodeTransaction(item) ?: return@mapNotNull null
            val acc = accounts[b.account_id]
            val currency = b.currency ?: acc?.currency ?: "PYG"
            val cents = amountTextToCents(b.amount, currency)
            TransactionListItemDto(
                id = PENDING_PREFIX + item.id, date = b.date, amount_cents = cents,
                signed_amount_cents = if (b.nature == "income") cents else -cents,
                currency = currency, name = b.name,
                classification = if (b.nature == "income") "income" else "expense",
                account = AccountRefDto(b.account_id, acc?.name ?: "", acc?.accountType ?: ""),
                created_at = "", updated_at = "", pending = true
            )
        }.reversed()
    }

    // Last synced 90-day window from Room, filtered client-side like the server would.
    private suspend fun loadOffline(): List<TransactionListItemDto>? {
        val eDao = entryDao ?: return null
        val entries = runCatching { eDao.observeAll().first() }.getOrNull() ?: return null
        if (entries.isEmpty() && outbox?.pendingItems?.value.isNullOrEmpty()) return null
        val txs = transactionDao?.let { runCatching { it.getAll() }.getOrNull() }.orEmpty().associateBy { it.id }
        val accounts = accountDao?.observeAll()?.first().orEmpty().associateBy { it.id }
        val deleted = outbox?.pendingItems?.value.orEmpty()
            .filter { it.kind == "transaction_delete" && !it.failed }.map { it.payload }.toSet()
        val st = _uiState.value
        val rows = entries.asSequence()
            .filter { it.entryableType == "Transaction" && it.id !in deleted }
            .filter { st.selectedAccountId == null || it.accountId == st.selectedAccountId }
            .filter { st.startDate == null || it.date >= st.startDate }
            .filter { st.endDate == null || it.date <= st.endDate }
            .filter { st.searchQuery.isBlank() || it.name.contains(st.searchQuery, ignoreCase = true) }
            .filter { st.selectedCategoryId == null || txs[it.id]?.categoryId == st.selectedCategoryId }
            .filter {
                when (st.selectedType) {
                    "income" -> it.amountCents > 0
                    "expense" -> it.amountCents < 0
                    else -> true
                }
            }
            .map { e ->
                val t = txs[e.id]
                val acc = accounts[e.accountId]
                TransactionListItemDto(
                    id = e.id, date = e.date, amount_cents = abs(e.amountCents), signed_amount_cents = e.amountCents,
                    currency = e.currency, name = e.name,
                    classification = if (e.amountCents > 0) "income" else "expense",
                    account = AccountRefDto(e.accountId, acc?.name ?: "", acc?.accountType ?: ""),
                    category = t?.categoryId?.let { CategoryRefDto(it, t.categoryName ?: "", "", "") },
                    merchant = t?.merchantId?.let { MerchantRefDto(it, t.merchantName ?: "") },
                    created_at = e.updatedAt, updated_at = e.updatedAt
                )
            }
            .toList()
        return pendingRows() + rows
    }

    fun refresh() {
        loadTransactions(resetPage = true)
    }
}
