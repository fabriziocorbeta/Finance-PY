package py.com.cdco.financespy.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.CreateTradeBody
import py.com.cdco.financespy.api.dto.CreateTradeRequest
import py.com.cdco.financespy.api.dto.DashboardDto
import py.com.cdco.financespy.api.dto.MarketQuoteDto
import py.com.cdco.financespy.api.dto.PortfolioHoldingDto
import py.com.cdco.financespy.sync.OfflineCache
import py.com.cdco.financespy.sync.OfflineCacheKeys
import py.com.cdco.financespy.sync.OfflineStore

data class AggregatedHolding(
    val securityId: String,
    val ticker: String,
    val name: String,
    val currency: String,
    val qty: Double,
    val avgCostCents: Long?,
    val amountCents: Long,
    val accountsCount: Int
)

data class InvestmentsListState(
    val isLoading: Boolean = false,
    val isLoadingMarket: Boolean = false,
    val isMutatingWatchlist: Boolean = false,
    val error: String? = null,
    val marketError: String? = null,
    val investmentAccounts: List<AccountDto> = emptyList(),
    val holdingsBySecurity: List<AggregatedHolding> = emptyList(),
    val totalPortfolioValueCents: Long = 0,
    val currency: String = "PYG",
    val indexQuotes: List<MarketQuoteDto> = emptyList(),
    val watchlistQuotes: List<MarketQuoteDto> = emptyList(),
    val holdingQuotesBySecurity: Map<String, MarketQuoteDto> = emptyMap(),
    val featuredQuote: MarketQuoteDto? = null,
    val dialogQuote: MarketQuoteDto? = null,
    val selectedTicker: String = "^GSPC",
    val selectedRange: String = "1mo"
)

class InvestmentsListViewModel(
    private val api: FinancePyApi,
    store: OfflineStore? = null
) : ViewModel() {

    private val cache = OfflineCache(store)
    private val _state = MutableStateFlow(InvestmentsListState())
    val state: StateFlow<InvestmentsListState> = _state.asStateFlow()

    init {
        loadFromCache()
    }

    private fun loadFromCache() {
        val accounts = cache.getList(OfflineCacheKeys.ACCOUNTS_LIST, AccountDto.serializer())
        val holdings = cache.getList(OfflineCacheKeys.HOLDINGS_LIST, PortfolioHoldingDto.serializer())
        val dashboard = cache.get(OfflineCacheKeys.DASHBOARD_DTO, DashboardDto.serializer())
        if (accounts != null || holdings != null) {
            applyHoldingsData(accounts ?: emptyList(), holdings ?: emptyList(), dashboard)
        }
    }

    private fun applyHoldingsData(
        allAccounts: List<AccountDto>,
        allHoldings: List<PortfolioHoldingDto>,
        dashboard: DashboardDto?
    ) {
        val investmentAccounts = allAccounts.filter { it.account_type == "investment" }
        val investmentAccountIds = investmentAccounts.map { it.id }.toSet()

        val currentHoldings = allHoldings
            .filter { it.account.id in investmentAccountIds }
            .groupBy { it.account.id to it.security.id }
            .mapNotNull { (_, snapshots) -> snapshots.maxByOrNull { it.date } }

        val bySecurity = currentHoldings
            .groupBy { it.security.id }
            .map { (securityId, snapshots) ->
                val totalQty = snapshots.sumOf { it.qty.toDoubleOrNull() ?: 0.0 }
                val avgCostWeighted = snapshots.mapNotNull { snap ->
                    val q = snap.qty.toDoubleOrNull() ?: 0.0
                    val ac = snap.avg_cost_cents
                    if (ac != null && q > 0.0) ac * q else null
                }
                val avgCostCents = if (avgCostWeighted.isNotEmpty() && totalQty > 0.0) {
                    (avgCostWeighted.sum() / totalQty).toLong()
                } else {
                    snapshots.firstOrNull()?.avg_cost_cents
                }
                AggregatedHolding(
                    securityId = securityId,
                    ticker = snapshots.first().security.ticker,
                    name = snapshots.first().security.name ?: snapshots.first().security.ticker,
                    currency = snapshots.first().currency,
                    qty = totalQty,
                    avgCostCents = avgCostCents,
                    amountCents = snapshots.sumOf { it.amount_cents ?: 0L },
                    accountsCount = snapshots.map { it.account.id }.distinct().size
                )
            }
            .sortedByDescending { it.amountCents }

        val investmentSummary = dashboard?.investment_summary
        val currency = investmentSummary?.currency
            ?: investmentAccounts.firstOrNull()?.currency
            ?: bySecurity.firstOrNull()?.currency
            ?: "PYG"
        val totalPortfolioValueCents = investmentSummary?.portfolio_value_cents
            ?: bySecurity.sumOf { h -> h.amountCents }

        _state.update {
            it.copy(
                isLoading = false,
                investmentAccounts = investmentAccounts,
                holdingsBySecurity = bySecurity,
                totalPortfolioValueCents = totalPortfolioValueCents,
                currency = currency
            )
        }
    }

    fun refresh(forceMarketRefresh: Boolean = false) {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, isLoadingMarket = true, error = null, marketError = null) }
            try {
                val allAccounts = api.fetchAllAccounts()
                cache.putList(OfflineCacheKeys.ACCOUNTS_LIST, AccountDto.serializer(), allAccounts)
                val allHoldings = api.fetchAllHoldings()
                cache.putList(OfflineCacheKeys.HOLDINGS_LIST, PortfolioHoldingDto.serializer(), allHoldings)
                val dashboard = api.fetchDashboard()
                cache.put(OfflineCacheKeys.DASHBOARD_DTO, DashboardDto.serializer(), dashboard)
                applyHoldingsData(allAccounts, allHoldings, dashboard)
            } catch (e: Exception) {
                loadFromCache()
                val hasCached = _state.value.investmentAccounts.isNotEmpty() || _state.value.holdingsBySecurity.isNotEmpty()
                _state.update {
                    it.copy(
                        isLoading = false,
                        error = if (!hasCached) (e.message ?: "Error al cargar inversiones") else null
                    )
                }
            }

            loadMarketTracker(forceRefresh = forceMarketRefresh)
        }
    }

    fun selectQuote(ticker: String, range: String = _state.value.selectedRange) {
        viewModelScope.launch {
            _state.update { it.copy(selectedTicker = ticker, selectedRange = range, isLoadingMarket = true, marketError = null) }
            try {
                val response = api.fetchMarketQuote(ticker = ticker, range = range)
                _state.update {
                    it.copy(
                        isLoadingMarket = false,
                        featuredQuote = response.quote ?: it.featuredQuote
                    )
                }
            } catch (e: Exception) {
                _state.update {
                    it.copy(
                        isLoadingMarket = false,
                        marketError = e.message ?: "Error al cargar cotización"
                    )
                }
            }
        }
    }

    fun addToWatchlist(ticker: String) {
        val clean = ticker.trim().uppercase()
        if (clean.isEmpty()) return

        viewModelScope.launch {
            _state.update { it.copy(isMutatingWatchlist = true, marketError = null) }
            try {
                api.addWatchlistItem(ticker = clean)
                _state.update { it.copy(selectedTicker = clean, isMutatingWatchlist = false) }
                loadMarketTracker(forceRefresh = false)
            } catch (e: Exception) {
                _state.update {
                    it.copy(
                        isMutatingWatchlist = false,
                        marketError = e.message ?: "No se pudo agregar $clean"
                    )
                }
            }
        }
    }

    fun removeFromWatchlist(watchlistItemId: String) {
        viewModelScope.launch {
            _state.update { it.copy(isMutatingWatchlist = true, marketError = null) }
            try {
                api.deleteWatchlistItem(watchlistItemId)
                _state.update { it.copy(isMutatingWatchlist = false) }
                loadMarketTracker(forceRefresh = false)
            } catch (e: Exception) {
                _state.update {
                    it.copy(
                        isMutatingWatchlist = false,
                        marketError = e.message ?: "No se pudo eliminar de seguimiento"
                    )
                }
            }
        }
    }

    fun lookupQuoteForDialog(ticker: String) {
        val clean = ticker.trim().uppercase()
        if (clean.isEmpty()) {
            _state.update { it.copy(dialogQuote = null) }
            return
        }
        viewModelScope.launch {
            try {
                val response = api.fetchMarketQuote(ticker = clean, range = "1mo")
                _state.update { it.copy(dialogQuote = response.quote) }
            } catch (_: Exception) {
                // Ignore transient lookup errors while typing
            }
        }
    }

    fun recordTrade(
        accountId: String,
        type: String,
        ticker: String,
        qty: String,
        price: String,
        date: String
    ) {
        val cleanTicker = ticker.trim().uppercase()
        if (cleanTicker.isEmpty() || qty.isBlank() || price.isBlank()) return

        viewModelScope.launch {
            _state.update { it.copy(isMutatingWatchlist = true, marketError = null) }
            try {
                val resolvedTicker = if (cleanTicker.contains("|")) cleanTicker else "$cleanTicker||yahoo_finance"
                api.createTrade(
                    CreateTradeRequest(
                        trade = CreateTradeBody(
                            account_id = accountId,
                            type = type,
                            ticker = resolvedTicker,
                            qty = qty.trim(),
                            price = price.trim(),
                            date = date.trim()
                        )
                    )
                )
                _state.update { it.copy(isMutatingWatchlist = false, selectedTicker = cleanTicker) }
                refresh(forceMarketRefresh = false)
            } catch (e: Exception) {
                _state.update {
                    it.copy(
                        isMutatingWatchlist = false,
                        marketError = e.message ?: "No se pudo registrar la posición"
                    )
                }
            }
        }
    }

    private suspend fun loadMarketTracker(forceRefresh: Boolean) {
        try {
            val current = _state.value
            val tracker = api.fetchMarketTracker(
                ticker = current.selectedTicker,
                range = current.selectedRange,
                refresh = forceRefresh
            )
            _state.update {
                it.copy(
                    isLoadingMarket = false,
                    indexQuotes = tracker.index_quotes,
                    watchlistQuotes = tracker.watchlist_quotes,
                    holdingQuotesBySecurity = tracker.holding_quotes
                        .filter { q -> q.security_id != null }
                        .associateBy { q -> q.security_id!! },
                    featuredQuote = tracker.featured_quote ?: it.featuredQuote
                )
            }
        } catch (e: Exception) {
            _state.update {
                it.copy(
                    isLoadingMarket = false,
                    marketError = e.message
                )
            }
        }
    }
}
