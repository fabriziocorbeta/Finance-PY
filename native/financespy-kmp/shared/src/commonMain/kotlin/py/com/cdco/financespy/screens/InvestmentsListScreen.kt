package py.com.cdco.financespy.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.ButtonVariant
import py.com.cdco.financespy.utils.formatMoney
import py.com.cdco.financespy.utils.formatPercent

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun InvestmentsListScreen(
    viewModel: InvestmentsListViewModel,
    onAccountClick: (String) -> Unit,
    onHoldingClick: (String) -> Unit,
    onViewPerformanceClick: () -> Unit,
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.refresh()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Inversiones", style = MaterialTheme.typography.titleLarge) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Volver")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = FinancePyColors.container(),
                    titleContentColor = FinancePyColors.textPrimary()
                )
            )
        },
        containerColor = FinancePyColors.surface()
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when {
                state.isLoading && state.investmentAccounts.isEmpty() && state.holdingsBySecurity.isEmpty() -> {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                }
                state.error != null && state.investmentAccounts.isEmpty() -> {
                    Column(
                        modifier = Modifier.align(Alignment.Center).padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = state.error ?: "Error",
                            color = MaterialTheme.colorScheme.error,
                            style = MaterialTheme.typography.bodyMedium,
                            textAlign = TextAlign.Center
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        AppButton(text = "Reintentar", onClick = { viewModel.refresh() })
                    }
                }
                state.investmentAccounts.isEmpty() -> {
                    Text(
                        text = "No tenés cuentas de inversión registradas",
                        modifier = Modifier.align(Alignment.Center).padding(16.dp),
                        textAlign = TextAlign.Center,
                        color = FinancePyColors.textSecondary()
                    )
                }
                else -> {
                    LazyColumn(
                        modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        item { Spacer(modifier = Modifier.height(4.dp)) }

                        item {
                            PortfolioSummaryHeaderCard(
                                totalValueCents = state.totalPortfolioValueCents,
                                currency = state.currency,
                                accountsCount = state.investmentAccounts.size,
                                onViewPerformanceClick = onViewPerformanceClick
                            )
                        }

                        item {
                            Text(
                                text = "Cuentas de inversión",
                                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                color = FinancePyColors.textPrimary()
                            )
                        }

                        items(state.investmentAccounts) { account ->
                            InvestmentAccountRow(account = account, onClick = { onAccountClick(account.id) })
                        }

                        if (state.holdingsBySecurity.isNotEmpty()) {
                            item {
                                Text(
                                    text = "Activos del portafolio",
                                    style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                    color = FinancePyColors.textPrimary()
                                )
                            }

                            item {
                                AppCard(modifier = Modifier.fillMaxWidth()) {
                                    Column(modifier = Modifier.padding(16.dp)) {
                                        state.holdingsBySecurity.forEachIndexed { idx, holding ->
                                            if (idx > 0) Spacer(modifier = Modifier.height(12.dp))
                                            HoldingSecurityRow(
                                                holding = holding,
                                                totalValueCents = state.totalPortfolioValueCents,
                                                onClick = { onHoldingClick(holding.securityId) }
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        item { Spacer(modifier = Modifier.height(24.dp)) }
                    }
                }
            }
        }
    }
}

@Composable
private fun PortfolioSummaryHeaderCard(
    totalValueCents: Long,
    currency: String,
    accountsCount: Int,
    onViewPerformanceClick: () -> Unit
) {
    AppCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Valor total del portafolio",
                style = MaterialTheme.typography.bodySmall,
                color = FinancePyColors.textSecondary()
            )
            Text(
                text = formatMoney(totalValueCents, currency),
                style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = "$accountsCount cuenta${if (accountsCount == 1) "" else "s"} de inversión",
                style = MaterialTheme.typography.labelSmall,
                color = FinancePyColors.textSecondary()
            )
            Spacer(modifier = Modifier.height(12.dp))
            AppButton(
                text = "Ver rendimiento",
                onClick = onViewPerformanceClick,
                variant = ButtonVariant.Secondary,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

@Composable
private fun InvestmentAccountRow(account: AccountDto, onClick: () -> Unit) {
    AppCard(modifier = Modifier.fillMaxWidth().clickable { onClick() }) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column {
                Text(
                    text = account.name,
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = FinancePyColors.textPrimary()
                )
                account.institution_name?.let {
                    Text(
                        text = it,
                        style = MaterialTheme.typography.labelSmall,
                        color = FinancePyColors.textSecondary()
                    )
                }
            }
            Text(
                text = formatMoney(account.balance_cents, account.currency),
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
        }
    }
}

@Composable
private fun HoldingSecurityRow(holding: AggregatedHolding, totalValueCents: Long, onClick: () -> Unit) {
    val weightPct = if (totalValueCents > 0) (holding.amountCents * 100.0 / totalValueCents) else 0.0
    Row(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = holding.ticker,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
            Text(
                text = holding.name,
                style = MaterialTheme.typography.labelSmall,
                color = FinancePyColors.textSecondary(),
                maxLines = 1
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = formatMoney(holding.amountCents, holding.currency),
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
            Text(
                text = "${formatPercent(weightPct)} del portafolio",
                style = MaterialTheme.typography.labelSmall,
                color = FinancePyColors.textSecondary()
            )
        }
    }
}
