package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.CategoryDto
import py.com.cdco.financespy.api.dto.MerchantDto
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.api.dto.TransactionsResponse

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
    val hasMorePages: Boolean = false
)

class TransactionsViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi
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
                    transactions = response.transactions,
                    currentPage = page,
                    hasMorePages = page < response.pagination.total_pages
                )
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Error al cargar las transacciones"
                )
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
                api.deleteTransaction(id)
                loadTransactions(resetPage = true)
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(error = e.message ?: "Error al eliminar la transacción")
            } finally {
                onDone()
            }
        }
    }

    fun refresh() {
        loadTransactions(resetPage = true)
    }
}
