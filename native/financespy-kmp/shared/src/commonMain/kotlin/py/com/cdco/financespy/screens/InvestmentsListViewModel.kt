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
import py.com.cdco.financespy.api.dto.DashboardDto
import py.com.cdco.financespy.api.dto.PortfolioHoldingDto
import py.com.cdco.financespy.sync.OfflineCache
import py.com.cdco.financespy.sync.OfflineCacheKeys
import py.com.cdco.financespy.sync.OfflineStore

data class AggregatedHolding(
    val securityId: String,
    val ticker: String,
    val name: String,
    val currency: String,
    val amountCents: Long,
    val accountsCount: Int
)

data class InvestmentsListState(
    val isLoading: Boolean = false,
    val error: String? = null,
    val investmentAccounts: List<AccountDto> = emptyList(),
    val holdingsBySecurity: List<AggregatedHolding> = emptyList(),
    val totalPortfolioValueCents: Long = 0,
    val currency: String = "PYG"
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
                AggregatedHolding(
                    securityId = securityId,
                    ticker = snapshots.first().security.ticker,
                    name = snapshots.first().security.name ?: snapshots.first().security.ticker,
                    currency = snapshots.first().currency,
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

    fun refresh() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
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
        }
    }
}
