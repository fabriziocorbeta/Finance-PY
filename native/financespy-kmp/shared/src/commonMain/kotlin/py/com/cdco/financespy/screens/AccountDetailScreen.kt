package py.com.cdco.financespy.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.BalanceSeriesPointDto
import py.com.cdco.financespy.screens.components.parseColorString
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.utils.formatMoney

@Composable
fun AccountDetailScreen(viewModel: AccountDetailViewModel) {
    val state by viewModel.state.collectAsState()

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface()),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        state.account?.let { account ->
            item {
                AppCard(modifier = Modifier.fillMaxWidth()) {
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = account.name,
                            style = MaterialTheme.typography.titleLarge,
                            color = FinancePyColors.textPrimary()
                        )
                        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                            Text(
                                text = "Saldo: ${formatMoney(account.balanceCents, account.currency)}",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            Text(
                                text = "Saldo efectivo: ${formatMoney(account.cashBalanceCents, account.currency)}",
                                style = MaterialTheme.typography.bodyMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            Text(
                                text = "Tipo: ${account.accountType}${account.subtype?.let { " ($it)" } ?: ""}",
                                style = MaterialTheme.typography.labelMedium,
                                color = FinancePyColors.textSubdued()
                            )
                        }
                    }
                }
            }
        }

        item {
            AppCard(modifier = Modifier.fillMaxWidth()) {
                Column(
                    modifier = Modifier.padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    Text(
                        text = "Historial de balance",
                        style = MaterialTheme.typography.titleMedium,
                        color = FinancePyColors.textPrimary()
                    )

                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        val periods = listOf(
                            "last_30_days" to "30 días",
                            "last_90_days" to "90 días",
                            "last_365_days" to "1 año"
                        )
                        periods.forEach { (key, label) ->
                            FilterChip(
                                selected = state.seriesPeriod == key,
                                onClick = { viewModel.changePeriod(key) },
                                label = { Text(label) },
                                colors = FilterChipDefaults.filterChipColors(
                                    containerColor = FinancePyColors.container(),
                                    labelColor = FinancePyColors.textPrimary(),
                                    selectedContainerColor = FinancePyColors.buttonBgPrimary(),
                                    selectedLabelColor = FinancePyColors.surface()
                                )
                            )
                        }
                    }

                    if (state.isLoadingSeries) {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(120.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator(
                                color = FinancePyColors.buttonBgPrimary(),
                                modifier = Modifier.size(24.dp)
                            )
                        }
                    } else {
                        val series = state.balanceSeries?.series ?: emptyList()
                        if (series.size < 2) {
                            Box(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(120.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "Datos no disponibles para el período seleccionado",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = FinancePyColors.textSecondary()
                                )
                            }
                        } else {
                            val primaryColor = FinancePyColors.buttonBgPrimary()
                            AccountBalanceLineChartCanvas(
                                series = series,
                                lineColor = primaryColor,
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .height(140.dp)
                            )
                        }

                        state.balanceSeries?.trend?.let { tr ->
                            val successColor = FinancePyColors.success()
                            val destructiveColor = FinancePyColors.destructive()
                            val warningColor = FinancePyColors.warning()
                            val primaryColor = FinancePyColors.buttonBgPrimary()
                            val defaultTrendColor = if (tr.direction == "up") successColor else destructiveColor
                            val trendColor = parseColorString(
                                tr.color, defaultTrendColor, successColor, destructiveColor, warningColor, primaryColor
                            )
                            val arrow = if (tr.direction == "up") "▲ " else if (tr.direction == "down") "▼ " else ""
                            val currency = state.balanceSeries?.currency ?: state.account?.currency ?: "PYG"
                            val valChange = tr.value
                            val valText = if (valChange != null) formatMoney(valChange, currency) else null
                            val pctText = tr.percent_formatted ?: tr.percent?.let { "${it}%" }
                            val summary = listOfNotNull(valText, pctText?.let { "($it)" }).joinToString(" ")

                            if (summary.isNotEmpty()) {
                                Text(
                                    text = "$arrow$summary este período",
                                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                    color = trendColor
                                )
                            }
                        }
                    }
                }
            }
        }

        item {
            Text(
                text = "Transacciones",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary(),
                modifier = Modifier.padding(top = 8.dp)
            )
        }

        items(state.entries) { entry ->
            AppCard(modifier = Modifier.fillMaxWidth()) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = entry.name,
                            style = MaterialTheme.typography.titleMedium,
                            color = FinancePyColors.textPrimary()
                        )
                        Text(
                            text = entry.date,
                            style = MaterialTheme.typography.labelMedium,
                            color = FinancePyColors.textSubdued()
                        )
                    }
                    Text(
                        text = formatMoney(entry.amountCents, entry.currency),
                        style = MaterialTheme.typography.bodyMedium,
                        color = FinancePyColors.textSecondary()
                    )
                }
            }
        }
    }
}

@Composable
private fun AccountBalanceLineChartCanvas(
    series: List<BalanceSeriesPointDto>,
    lineColor: Color,
    modifier: Modifier = Modifier
) {
    val minVal = series.minOf { it.balance }
    val maxVal = series.maxOf { it.balance }
    val range = (maxVal - minVal).let { if (it == 0.0) 1.0 else it }

    Box(modifier = modifier) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val widthPx = size.width
            val heightPx = size.height
            val paddingY = 16.dp.toPx()
            val drawHeight = heightPx - 2 * paddingY

            val points = series.mapIndexed { idx, item ->
                val x = (idx.toFloat() / (series.size - 1)) * widthPx
                val y = heightPx - paddingY - (((item.balance - minVal) / range) * drawHeight).toFloat()
                Offset(x, y)
            }

            val path = Path().apply {
                points.forEachIndexed { i, pt ->
                    if (i == 0) moveTo(pt.x, pt.y) else lineTo(pt.x, pt.y)
                }
            }

            val fillPath = Path().apply {
                addPath(path)
                lineTo(widthPx, heightPx)
                lineTo(0f, heightPx)
                close()
            }

            drawPath(
                path = fillPath,
                brush = Brush.verticalGradient(
                    colors = listOf(lineColor.copy(alpha = 0.25f), Color.Transparent)
                )
            )

            drawPath(
                path = path,
                color = lineColor,
                style = Stroke(width = 3.dp.toPx())
            )

            points.lastOrNull()?.let { lastPt ->
                drawCircle(
                    color = lineColor,
                    radius = 5.dp.toPx(),
                    center = lastPt
                )
            }
        }
    }
}
