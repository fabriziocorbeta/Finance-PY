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
    private val api: FinancePyApi
) : ViewModel() {

    private val _state = MutableStateFlow(InvestmentsListState())
    val state: StateFlow<InvestmentsListState> = _state.asStateFlow()

    fun refresh() {
        viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                val investmentAccounts = api.fetchAllAccounts().filter { it.account_type == "investment" }
                val investmentAccountIds = investmentAccounts.map { it.id }.toSet()

                // Holdings are point-in-time snapshots (one row per account+security+date
                // the sync ran), so the current position is the latest-dated row per
                // (account, security) pair -- not the sum of every historical row.
                val currentHoldings = api.fetchAllHoldings()
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

                val currency = investmentAccounts.firstOrNull()?.currency
                    ?: bySecurity.firstOrNull()?.currency
                    ?: "PYG"

                _state.update {
                    it.copy(
                        isLoading = false,
                        investmentAccounts = investmentAccounts,
                        holdingsBySecurity = bySecurity,
                        totalPortfolioValueCents = bySecurity.sumOf { h -> h.amountCents },
                        currency = currency
                    )
                }
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, error = e.message ?: "Error al cargar inversiones") }
            }
        }
    }
}
