package py.com.cdco.financespy.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.ReportCategoryBreakdownDto
import py.com.cdco.financespy.api.dto.ReportNetWorthDto
import py.com.cdco.financespy.api.dto.ReportSummaryMetricsDto
import py.com.cdco.financespy.api.dto.ReportTrendItemDto
import py.com.cdco.financespy.api.dto.ReportsSummaryDto
import py.com.cdco.financespy.screens.components.parseColorString
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.utils.formatMoney

@Composable
fun ReportsScreen(
    viewModel: ReportsViewModel,
    modifier: Modifier = Modifier
) {
    val state by viewModel.state.collectAsState()

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
    ) {
        // Header
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Reportes",
                style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )

            IconButton(onClick = { viewModel.refresh() }) {
                Icon(
                    imageVector = Icons.Default.Refresh,
                    contentDescription = "Refrescar reportes",
                    tint = FinancePyColors.textPrimary()
                )
            }
        }

        // Period filter bar
        PeriodFilterChips(
            selectedPeriodType = state.selectedPeriodType,
            onSelectPeriod = { viewModel.selectPeriodType(it) },
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp)
        )

        Spacer(modifier = Modifier.height(8.dp))

        if (state.isLoading && state.reportsSummary == null) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = FinancePyColors.buttonBgPrimary())
            }
        } else if (state.error != null && state.reportsSummary == null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = state.error ?: "Error al cargar reportes",
                    style = MaterialTheme.typography.bodyMedium,
                    color = FinancePyColors.destructive(),
                    textAlign = TextAlign.Center
                )
            }
        } else {
            val summaryDto = state.reportsSummary
            if (summaryDto != null) {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    item {
                        SummaryMetricsCard(summary = summaryDto.summary)
                    }

                    item {
                        TrendsChartCard(trends = summaryDto.trends)
                    }

                    item {
                        CategoryBreakdownCard(breakdown = summaryDto.transactionsBreakdown)
                    }

                    item {
                        NetWorthReportCard(netWorth = summaryDto.netWorth)
                    }

                    item {
                        Spacer(modifier = Modifier.height(24.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun PeriodFilterChips(
    selectedPeriodType: String,
    onSelectPeriod: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    val periods = listOf(
        "monthly" to "Este mes",
        "quarterly" to "Trimestre",
        "ytd" to "Año",
        "last_6_months" to "6 meses"
    )

    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        periods.forEach { (key, label) ->
            val isSelected = selectedPeriodType == key
            val containerColor = if (isSelected) FinancePyColors.buttonBgPrimary() else FinancePyColors.container()
            val textColor = if (isSelected) FinancePyColors.surface() else FinancePyColors.textSecondary()

            Surface(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(20.dp))
                    .clickable { onSelectPeriod(key) },
                color = containerColor,
                shape = RoundedCornerShape(20.dp)
            ) {
                Box(
                    modifier = Modifier.padding(vertical = 8.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = label,
                        style = MaterialTheme.typography.labelMedium.copy(fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal),
                        color = textColor,
                        maxLines = 1
                    )
                }
            }
        }
    }
}

@Composable
private fun SummaryMetricsCard(
    summary: ReportSummaryMetricsDto,
    modifier: Modifier = Modifier
) {
    AppCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Resumen del Período",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )

            Spacer(modifier = Modifier.height(12.dp))

            BoxWithConstraints {
                if (maxWidth < 400.dp) {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        MetricItem(
                            label = "Ingresos",
                            amount = summary.income,
                            changePct = summary.incomeChangePct,
                            isIncome = true
                        )
                        MetricItem(
                            label = "Gastos",
                            amount = summary.expense,
                            changePct = summary.expenseChangePct,
                            isIncome = false
                        )
                    }
                } else {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        MetricItem(
                            label = "Ingresos",
                            amount = summary.income,
                            changePct = summary.incomeChangePct,
                            isIncome = true,
                            modifier = Modifier.weight(1f)
                        )
                        Spacer(modifier = Modifier.width(16.dp))
                        MetricItem(
                            label = "Gastos",
                            amount = summary.expense,
                            changePct = summary.expenseChangePct,
                            isIncome = false,
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = "Ahorro Neto",
                        style = MaterialTheme.typography.bodySmall,
                        color = FinancePyColors.textSecondary()
                    )
                    Text(
                        text = formatMoney(summary.netSavings, null),
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                        color = if (summary.netSavings >= 0) FinancePyColors.success() else FinancePyColors.destructive()
                    )
                }

                summary.budgetUsedPct?.let { pct ->
                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            text = "Presupuesto Utilizado",
                            style = MaterialTheme.typography.bodySmall,
                            color = FinancePyColors.textSecondary()
                        )
                        Text(
                            text = "${pct}%",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = if (pct > 100) FinancePyColors.destructive() else FinancePyColors.textPrimary()
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun MetricItem(
    label: String,
    amount: Double,
    changePct: Double,
    isIncome: Boolean,
    modifier: Modifier = Modifier
) {
    Column(modifier = modifier) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = FinancePyColors.textSecondary()
        )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Text(
                text = formatMoney(amount, null),
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )

            if (changePct != 0.0) {
                val isPositive = changePct > 0
                val color = if (isIncome) {
                    if (isPositive) FinancePyColors.success() else FinancePyColors.destructive()
                } else {
                    if (isPositive) FinancePyColors.destructive() else FinancePyColors.success()
                }
                val arrow = if (isPositive) "▲" else "▼"
                Text(
                    text = "$arrow ${if (isPositive) "+" else ""}${changePct}%",
                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                    color = color
                )
            }
        }
    }
}

@Composable
private fun TrendsChartCard(
    trends: List<ReportTrendItemDto>,
    modifier: Modifier = Modifier
) {
    AppCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Tendencias (Ingresos vs Gastos)",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )

            Spacer(modifier = Modifier.height(12.dp))

            val successColor = FinancePyColors.success()
            val destructiveColor = FinancePyColors.destructive()

            // Legend
            Row(
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Box(modifier = Modifier.size(10.dp).background(successColor, CircleShape))
                    Text("Ingresos", style = MaterialTheme.typography.bodySmall, color = FinancePyColors.textSecondary())
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Box(modifier = Modifier.size(10.dp).background(destructiveColor, CircleShape))
                    Text("Gastos", style = MaterialTheme.typography.bodySmall, color = FinancePyColors.textSecondary())
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            if (trends.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxWidth().height(140.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text("Sin datos de tendencias", style = MaterialTheme.typography.bodySmall, color = FinancePyColors.textSecondary())
                }
            } else {
                TrendsCanvasChart(
                    trends = trends,
                    incomeColor = successColor,
                    expenseColor = destructiveColor,
                    modifier = Modifier.fillMaxWidth().height(160.dp)
                )
            }
        }
    }
}

@Composable
private fun TrendsCanvasChart(
    trends: List<ReportTrendItemDto>,
    incomeColor: Color,
    expenseColor: Color,
    modifier: Modifier = Modifier
) {
    val maxVal = trends.maxOfOrNull { maxOf(it.income, it.expense) }?.let { if (it == 0.0) 1.0 else it } ?: 1.0

    Column(modifier = modifier) {
        Canvas(modifier = Modifier.weight(1f).fillMaxWidth()) {
            val widthPx = size.width
            val heightPx = size.height
            val itemCount = trends.size
            val groupWidth = widthPx / itemCount
            val barWidth = (groupWidth * 0.3f).coerceAtMost(24.dp.toPx())

            trends.forEachIndexed { idx, item ->
                val groupCenterX = idx * groupWidth + groupWidth / 2f

                // Income bar
                val incomeHeight = ((item.income / maxVal) * (heightPx - 10)).toFloat()
                val incomeX = groupCenterX - barWidth - 2.dp.toPx()
                val incomeY = heightPx - incomeHeight
                if (incomeHeight > 0) {
                    drawRect(
                        color = incomeColor,
                        topLeft = Offset(incomeX, incomeY),
                        size = Size(barWidth, incomeHeight)
                    )
                }

                // Expense bar
                val expenseHeight = ((item.expense / maxVal) * (heightPx - 10)).toFloat()
                val expenseX = groupCenterX + 2.dp.toPx()
                val expenseY = heightPx - expenseHeight
                if (expenseHeight > 0) {
                    drawRect(
                        color = expenseColor,
                        topLeft = Offset(expenseX, expenseY),
                        size = Size(barWidth, expenseHeight)
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(4.dp))

        // Month labels
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceAround
        ) {
            trends.forEach { item ->
                val label = item.monthName ?: item.month.takeLast(2)
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall,
                    color = if (item.isCurrentMonth) FinancePyColors.textPrimary() else FinancePyColors.textSecondary(),
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}

@Composable
private fun CategoryBreakdownCard(
    breakdown: py.com.cdco.financespy.api.dto.ReportTransactionsBreakdownDto,
    modifier: Modifier = Modifier
) {
    var selectedTab by remember { mutableStateOf(0) } // 0: Gastos, 1: Ingresos

    AppCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Desglose por Categorías",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )

            Spacer(modifier = Modifier.height(12.dp))

            TabRow(
                selectedTabIndex = selectedTab,
                containerColor = FinancePyColors.container(),
                contentColor = FinancePyColors.textPrimary()
            ) {
                Tab(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    text = { Text("Gastos (${breakdown.expense.size})", style = MaterialTheme.typography.labelMedium) }
                )
                Tab(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    text = { Text("Ingresos (${breakdown.income.size})", style = MaterialTheme.typography.labelMedium) }
                )
            }

            Spacer(modifier = Modifier.height(12.dp))

            val list = if (selectedTab == 0) breakdown.expense else breakdown.income

            if (list.isEmpty()) {
                Box(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "Sin transacciones en esta sección",
                        style = MaterialTheme.typography.bodySmall,
                        color = FinancePyColors.textSecondary()
                    )
                }
            } else {
                val successColor = FinancePyColors.success()
                val destructiveColor = FinancePyColors.destructive()
                val warningColor = FinancePyColors.warning()
                val primaryColor = FinancePyColors.buttonBgPrimary()

                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    list.forEach { category ->
                        CategoryBreakdownRow(
                            category = category,
                            successColor = successColor,
                            destructiveColor = destructiveColor,
                            warningColor = warningColor,
                            primaryColor = primaryColor
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CategoryBreakdownRow(
    category: ReportCategoryBreakdownDto,
    successColor: Color,
    destructiveColor: Color,
    warningColor: Color,
    primaryColor: Color
) {
    val catColor = parseColorString(
        category.categoryColor, primaryColor, successColor, destructiveColor, warningColor, primaryColor
    )

    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(12.dp)
                        .background(catColor, CircleShape)
                )
                Text(
                    text = category.categoryName,
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = FinancePyColors.textPrimary()
                )
            }

            Text(
                text = formatMoney(category.total, null),
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )
        }

        if (category.subcategories.isNotEmpty()) {
            Column(
                modifier = Modifier
                    .padding(start = 20.dp, top = 4.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                category.subcategories.forEach { sub ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Text(
                            text = sub.categoryName,
                            style = MaterialTheme.typography.bodySmall,
                            color = FinancePyColors.textSecondary()
                        )
                        Text(
                            text = formatMoney(sub.total, null),
                            style = MaterialTheme.typography.bodySmall,
                            color = FinancePyColors.textSecondary()
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun NetWorthReportCard(
    netWorth: ReportNetWorthDto,
    modifier: Modifier = Modifier
) {
    AppCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Patrimonio Neto",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = FinancePyColors.textPrimary()
            )

            Spacer(modifier = Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = formatMoney(netWorth.current, null),
                    style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                    color = FinancePyColors.textPrimary()
                )

                netWorth.changePct?.let { pct ->
                    val isPositive = pct >= 0
                    val color = if (isPositive) FinancePyColors.success() else FinancePyColors.destructive()
                    val arrow = if (isPositive) "▲" else "▼"
                    Text(
                        text = "$arrow ${if (isPositive) "+" else ""}${pct}%",
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                        color = color
                    )
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text(
                        text = "Activos totales",
                        style = MaterialTheme.typography.bodySmall,
                        color = FinancePyColors.textSecondary()
                    )
                    Text(
                        text = formatMoney(netWorth.totalAssets, null),
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                        color = FinancePyColors.success()
                    )
                }

                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        text = "Pasivos totales",
                        style = MaterialTheme.typography.bodySmall,
                        color = FinancePyColors.textSecondary()
                    )
                    Text(
                        text = formatMoney(netWorth.totalLiabilities, null),
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                        color = FinancePyColors.destructive()
                    )
                }
            }
        }
    }
}
