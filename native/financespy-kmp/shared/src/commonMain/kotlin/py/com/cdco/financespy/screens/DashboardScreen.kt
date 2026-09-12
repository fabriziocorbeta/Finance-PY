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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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
        "last_day" to "Hoy",
        "current_week" to "Esta semana",
        "last_7_days" to "Últimos 7 días",
        "current_month" to "Este mes",
        "last_month" to "Mes pasado",
        "last_30_days" to "Últimos 30 días",
        "last_90_days" to "Últimos 90 días",
        "current_year" to "Este año",
        "last_365_days" to "Últimos 365 días",
        "last_5_years" to "Últimos 5 años",
        "last_10_years" to "Últimos 10 años",
        "all_time" to "Todo"
    )

    var periodExpanded by remember { mutableStateOf(false) }
    val currentPeriodKey = state.selectedPeriod ?: dashboard?.period?.key ?: "current_month"
    val currentPeriodLabel = periodOptions.find { it.first == currentPeriodKey }?.second ?: "Este mes"

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

                Box {
                    Row(
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .background(FinancePyColors.container())
                            .clickable { periodExpanded = true }
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = currentPeriodLabel,
                            style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary()
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Icon(
                            imageVector = Icons.Default.ArrowDropDown,
                            contentDescription = null,
                            tint = FinancePyColors.textSecondary()
                        )
                    }

                    DropdownMenu(
                        expanded = periodExpanded,
                        onDismissRequest = { periodExpanded = false }
                    ) {
                        periodOptions.forEach { (key, label) ->
                            val isSelected = key == currentPeriodKey
                            DropdownMenuItem(
                                text = {
                                    Text(
                                        text = label,
                                        style = MaterialTheme.typography.bodyMedium.copy(
                                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal
                                        ),
                                        color = if (isSelected) FinancePyColors.buttonBgPrimary() else FinancePyColors.textPrimary()
                                    )
                                },
                                onClick = {
                                    periodExpanded = false
                                    viewModel.selectPeriod(key)
                                }
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
