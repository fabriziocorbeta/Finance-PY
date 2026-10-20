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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
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
import androidx.compose.ui.unit.sp
import py.com.cdco.financespy.api.dto.DashboardDto
import py.com.cdco.financespy.screens.components.BalanceSheetBreakdownCard
import py.com.cdco.financespy.screens.components.InvestmentSummaryCard
import py.com.cdco.financespy.screens.components.NetWorthChartCard
import py.com.cdco.financespy.screens.components.OutflowsDonutCard
import py.com.cdco.financespy.screens.components.SankeyFlowChart
import py.com.cdco.financespy.screens.components.parseColorString
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.LocalUiVariant
import py.com.cdco.financespy.theme.UiVariant
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppBottomNavOverlayClearance
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.ButtonVariant
import py.com.cdco.financespy.utils.formatMoney

@Composable
fun DashboardScreen(
    viewModel: DashboardViewModel,
    onAccountClick: (String) -> Unit = {},
    onSettingsClick: () -> Unit = {},
    onAddAccount: () -> Unit = {}
) {
    val variant = LocalUiVariant.current
    if (variant == UiVariant.IOS) {
        IosDashboardScreen(
            viewModel = viewModel,
            onAccountClick = onAccountClick,
            onSettingsClick = onSettingsClick,
            onAddAccount = onAddAccount
        )
        return
    }

    val state by viewModel.state.collectAsState()
    val dashboard = state.dashboard

    val periodOptions = remember { dashboardPeriodOptions() }

    var periodExpanded by remember { mutableStateOf(false) }
    val currentPeriodKey = state.selectedPeriod ?: dashboard?.period?.key ?: "current_month"
    val currentPeriodLabel = periodOptions.find { it.first == currentPeriodKey }?.second ?: "Este mes"

    val currentClearance = AppBottomNavOverlayClearance

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface()),
        contentPadding = PaddingValues(start = 16.dp, top = 16.dp, end = 16.dp, bottom = currentClearance),
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
                        IconButton(onClick = onSettingsClick) {
                            Icon(
                                imageVector = Icons.Default.Settings,
                                contentDescription = "Ajustes",
                                tint = FinancePyColors.textPrimary()
                            )
                        }
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

        val hasNoAccounts = dashboard != null &&
            dashboard.balance_sheet?.classification_groups.isNullOrEmpty()

        if (hasNoAccounts) {
            item {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(FinancePyColors.container())
                        .padding(16.dp)
                ) {
                    Column {
                        Text(
                            text = "Todavía no tenés cuentas",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary()
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Agregá una cuenta para empezar a ver tus finanzas.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textSecondary()
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        Button(onClick = onAddAccount) {
                            Text("Agregar cuenta")
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

// Variante iOS (Apple HIG + paridad visual con DashboardView.swift de
// financespy-ios): barra superior estilo NavigationStack con acciones en
// systemBlue, Large Title "Inicio" de 34sp, tarjeta hero centrada de
// Patrimonio Neto con desglose Activos/Pasivos, cuentas en listas Inset
// Grouped de 10dp con separadores hairline, y tarjetas de flujo/salidas.
@Composable
private fun IosDashboardScreen(
    viewModel: DashboardViewModel,
    onAccountClick: (String) -> Unit,
    onSettingsClick: () -> Unit,
    onAddAccount: () -> Unit
) {
    val state by viewModel.state.collectAsState()
    val dashboard = state.dashboard
    val periodOptions = remember { dashboardPeriodOptions() }

    var periodExpanded by remember { mutableStateOf(false) }
    val currentPeriodKey = state.selectedPeriod ?: dashboard?.period?.key ?: "current_month"
    val currentPeriodLabel = periodOptions.find { it.first == currentPeriodKey }?.second ?: "Este mes"

    Surface(
        modifier = Modifier.fillMaxSize(),
        color = FinancePyColors.surface()
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(FinancePyColors.surface())
        ) {
        // iOS Navigation Bar (ToolbarItem leading: Period Menu, trailing: Actualizar + Ajustes)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box {
                Row(
                    modifier = Modifier
                        .clip(RoundedCornerShape(16.dp))
                        .background(FinancePyColors.buttonBgPrimary().copy(alpha = 0.12f))
                        .clickable { periodExpanded = true }
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = currentPeriodLabel,
                        style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                        color = FinancePyColors.buttonBgPrimary()
                    )
                    Spacer(modifier = Modifier.width(2.dp))
                    Icon(
                        imageVector = Icons.Default.ArrowDropDown,
                        contentDescription = null,
                        tint = FinancePyColors.buttonBgPrimary(),
                        modifier = Modifier.size(18.dp)
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
                                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal
                                    ),
                                    color = if (isSelected) FinancePyColors.buttonBgPrimary() else FinancePyColors.textPrimary()
                                )
                            },
                            trailingIcon = if (isSelected) {
                                {
                                    Icon(
                                        imageVector = Icons.Default.Check,
                                        contentDescription = null,
                                        tint = FinancePyColors.buttonBgPrimary(),
                                        modifier = Modifier.size(16.dp)
                                    )
                                }
                            } else null,
                            onClick = {
                                periodExpanded = false
                                viewModel.selectPeriod(key)
                            }
                        )
                    }
                }
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (state.isSyncing) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        strokeWidth = 2.dp,
                        color = FinancePyColors.buttonBgPrimary()
                    )
                } else {
                    Text(
                        text = "Actualizar",
                        style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Normal),
                        color = FinancePyColors.buttonBgPrimary(),
                        modifier = Modifier.clickable { viewModel.refresh() }
                    )
                }
                IconButton(
                    onClick = onSettingsClick,
                    modifier = Modifier.size(32.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Settings,
                        contentDescription = "Ajustes",
                        tint = FinancePyColors.buttonBgPrimary(),
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }

        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(
                start = 16.dp,
                top = 4.dp,
                end = 16.dp,
                bottom = AppBottomNavOverlayClearance + 16.dp
            ),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            // iOS Large Title + greeting subtitle
            item {
                Column(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = "Inicio",
                        style = MaterialTheme.typography.headlineLarge,
                        color = FinancePyColors.textPrimary()
                    )
                    val greetingName = dashboard?.greeting_name ?: ""
                    val subtitle = if (greetingName.isNotBlank()) {
                        "Bienvenido de nuevo, $greetingName"
                    } else {
                        "Resumen de tus cuentas y patrimonio"
                    }
                    Spacer(modifier = Modifier.height(2.dp))
                    Text(
                        text = subtitle,
                        style = MaterialTheme.typography.bodyMedium,
                        color = FinancePyColors.textSecondary()
                    )

                    state.syncError?.let { err ->
                        Spacer(modifier = Modifier.height(6.dp))
                        Text(
                            text = err,
                            style = MaterialTheme.typography.bodySmall,
                            color = FinancePyColors.destructive()
                        )
                    }
                }
            }

            // Hero Net Worth Card (replica de DashboardView.swift líneas 22-64)
            item {
                IosNetWorthHeroCard(dashboard = dashboard)
            }

            val hasNoAccounts = dashboard != null &&
                dashboard.balance_sheet?.classification_groups.isNullOrEmpty()

            if (hasNoAccounts) {
                item {
                    AppCard(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = "No hay cuentas guardadas",
                            style = MaterialTheme.typography.titleMedium,
                            color = FinancePyColors.textPrimary()
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Agregá una cuenta para empezar a seguir tu patrimonio y movimientos.",
                            style = MaterialTheme.typography.bodySmall,
                            color = FinancePyColors.textSecondary()
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                        AppButton(
                            text = "Agregar cuenta",
                            onClick = onAddAccount,
                            variant = ButtonVariant.Primary,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                }
            } else {
                // Cuentas y Balance en formato Inset Grouped List de iOS
                item {
                    BalanceSheetBreakdownCard(
                        balanceSheet = dashboard?.balance_sheet,
                        currency = dashboard?.currency ?: "PYG",
                        onAccountClick = onAccountClick
                    )
                }
            }

            // Evolución de Patrimonio Neto (gráfico de línea)
            item {
                NetWorthChartCard(netWorth = dashboard?.net_worth)
            }

            // Flujo de caja (Sankey)
            item {
                SankeyFlowChart(
                    sankeyDto = dashboard?.cashflow_sankey,
                    currency = dashboard?.currency ?: "PYG"
                )
            }

            // Salidas por categoría (Donut)
            item {
                OutflowsDonutCard(outflowsDonut = dashboard?.outflows_donut)
            }

            dashboard?.investment_summary?.let { inv ->
                item {
                    InvestmentSummaryCard(investmentSummary = inv)
                }
            }
        }
    }
    }
}

@Composable
private fun IosNetWorthHeroCard(dashboard: DashboardDto?) {
    val currency = dashboard?.net_worth?.currency ?: dashboard?.currency ?: "PYG"
    val netWorthAmount = dashboard?.net_worth?.amount ?: 0.0
    val trend = dashboard?.net_worth?.trend
    val groups = dashboard?.balance_sheet?.classification_groups ?: emptyList()

    val assetsTotal = groups
        .filter {
            it.classification.equals("asset", ignoreCase = true) ||
                it.classification.equals("assets", ignoreCase = true) ||
                it.name.contains("activo", ignoreCase = true)
        }
        .sumOf { it.total }
    val liabilitiesTotal = groups
        .filter {
            it.classification.equals("liability", ignoreCase = true) ||
                it.classification.equals("liabilities", ignoreCase = true) ||
                it.name.contains("pasivo", ignoreCase = true) ||
                it.name.contains("deuda", ignoreCase = true)
        }
        .sumOf { it.total }

    val successColor = FinancePyColors.success()
    val destructiveColor = FinancePyColors.destructive()
    val warningColor = FinancePyColors.warning()
    val primaryColor = FinancePyColors.buttonBgPrimary()

    AppCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.fillMaxWidth(),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "Patrimonio Neto",
                style = MaterialTheme.typography.labelMedium,
                color = FinancePyColors.textSecondary()
            )
            Spacer(modifier = Modifier.height(6.dp))
            Text(
                text = formatMoney(netWorthAmount, currency),
                style = MaterialTheme.typography.displayMedium.copy(
                    fontSize = 32.sp,
                    fontWeight = FontWeight.Bold
                ),
                color = FinancePyColors.textPrimary()
            )

            trend?.let { tr ->
                val defaultTrendColor = if (tr.direction == "up") successColor else destructiveColor
                val trendColor = parseColorString(
                    tr.color, defaultTrendColor, successColor, destructiveColor, warningColor, primaryColor
                )
                val arrow = if (tr.direction == "up") "▲ " else if (tr.direction == "down") "▼ " else ""
                val text = tr.percent_formatted ?: "${tr.percent}%"

                Spacer(modifier = Modifier.height(6.dp))
                Box(
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(trendColor.copy(alpha = 0.14f))
                        .padding(horizontal = 10.dp, vertical = 3.dp)
                ) {
                    Text(
                        text = "$arrow$text",
                        style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                        color = trendColor
                    )
                }
            }

            if (groups.isNotEmpty()) {
                Spacer(modifier = Modifier.height(14.dp))
                HorizontalDivider(
                    thickness = 0.5.dp,
                    color = FinancePyColors.borderSecondary()
                )
                Spacer(modifier = Modifier.height(12.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceEvenly,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = "Activos",
                            style = MaterialTheme.typography.labelSmall,
                            color = FinancePyColors.textSecondary()
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = formatMoney(assetsTotal, currency),
                            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                            color = successColor
                        )
                    }
                    Box(
                        modifier = Modifier
                            .width(0.5.dp)
                            .height(28.dp)
                            .background(FinancePyColors.borderSecondary())
                    )
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = "Pasivos",
                            style = MaterialTheme.typography.labelSmall,
                            color = FinancePyColors.textSecondary()
                        )
                        Spacer(modifier = Modifier.height(2.dp))
                        Text(
                            text = formatMoney(liabilitiesTotal, currency),
                            style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.SemiBold),
                            color = destructiveColor
                        )
                    }
                }
            }
        }
    }
}

private fun dashboardPeriodOptions(): List<Pair<String, String>> = listOf(
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
