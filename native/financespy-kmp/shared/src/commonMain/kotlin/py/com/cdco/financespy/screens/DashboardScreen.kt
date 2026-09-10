package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.screens.components.BalanceSheetBreakdownCard
import py.com.cdco.financespy.screens.components.InvestmentSummaryCard
import py.com.cdco.financespy.screens.components.NetWorthChartCard
import py.com.cdco.financespy.screens.components.OutflowsDonutCard
import py.com.cdco.financespy.screens.components.SankeyFlowChart
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton

@Composable
fun DashboardScreen(
    viewModel: DashboardViewModel,
    onAccountClick: (String) -> Unit = {}
) {
    val state by viewModel.state.collectAsState()
    val dashboard = state.dashboard

    val periodOptions = listOf(
        "current_month" to "Mes actual",
        "last_30_days" to "Últimos 30 días",
        "year_to_date" to "Año actual",
        "all_time" to "Todo"
    )

    val primaryBgColor = FinancePyColors.buttonBgPrimary()
    val containerBgColor = FinancePyColors.container()
    val surfaceColor = FinancePyColors.surface()
    val textPrimaryColor = FinancePyColors.textPrimary()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface()),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            Column(modifier = Modifier.fillMaxWidth()) {
                val greetingName = dashboard?.greeting_name ?: ""
                val welcomeText = if (greetingName.isNotBlank()) {
                    "Bienvenido de nuevo, $greetingName"
                } else {
                    "Bienvenido de nuevo"
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = welcomeText,
                            style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary()
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Esto es lo que está pasando con tus finanzas",
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textSecondary()
                        )
                    }

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (state.isSyncing) {
                            CircularProgressIndicator(
                                modifier = Modifier.padding(end = 8.dp),
                                color = FinancePyColors.buttonBgPrimary()
                            )
                        }
                        AppButton(
                            text = "Actualizar",
                            onClick = { viewModel.refresh() }
                        )
                    }
                }

                state.syncError?.let { err ->
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = "Error: $err",
                        style = MaterialTheme.typography.bodySmall,
                        color = FinancePyColors.destructive()
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))

                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    items(periodOptions) { (key, label) ->
                        val isSelected = (state.selectedPeriod ?: "current_month") == key
                        Box(
                            modifier = Modifier
                                .clip(RoundedCornerShape(16.dp))
                                .background(if (isSelected) primaryBgColor else containerBgColor)
                                .clickable { viewModel.selectPeriod(key) }
                                .padding(horizontal = 12.dp, vertical = 6.dp)
                        ) {
                            Text(
                                text = label,
                                style = MaterialTheme.typography.labelMedium.copy(
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                                ),
                                color = if (isSelected) surfaceColor else textPrimaryColor
                            )
                        }
                    }
                }
            }
        }

        item {
            SankeyFlowChart(sankeyDto = dashboard?.cashflow_sankey, currency = dashboard?.currency ?: "PYG")
        }

        item {
            OutflowsDonutCard(outflowsDonut = dashboard?.outflows_donut)
        }

        item {
            NetWorthChartCard(netWorth = dashboard?.net_worth)
        }

        item {
            BalanceSheetBreakdownCard(
                balanceSheet = dashboard?.balance_sheet,
                currency = dashboard?.currency ?: "PYG",
                onAccountClick = onAccountClick
            )
        }

        dashboard?.investment_summary?.let { inv ->
            item {
                InvestmentSummaryCard(investmentSummary = inv)
            }
        }
    }
}
