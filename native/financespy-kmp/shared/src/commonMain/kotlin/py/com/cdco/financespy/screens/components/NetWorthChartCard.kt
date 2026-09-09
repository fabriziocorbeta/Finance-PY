package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.api.dto.NetWorthDto
import py.com.cdco.financespy.api.dto.NetWorthSeriesPointDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.utils.formatMoney

@Composable
fun NetWorthChartCard(
    netWorth: NetWorthDto?,
    modifier: Modifier = Modifier
) {
    AppCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Patrimonio neto",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary()
            )

            val amount = netWorth?.amount ?: 0.0
            val currency = netWorth?.currency ?: "PYG"
            val trend = netWorth?.trend
            val series = netWorth?.series ?: emptyList()

            val successColor = FinancePyColors.success()
            val destructiveColor = FinancePyColors.destructive()
            val warningColor = FinancePyColors.warning()
            val primaryColor = FinancePyColors.buttonBgPrimary()

            Spacer(modifier = Modifier.height(8.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = formatMoney(amount, currency),
                    style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
                    color = FinancePyColors.textPrimary()
                )

                trend?.let { tr ->
                    val defaultTrendColor = if (tr.direction == "up") successColor else destructiveColor
                    val trendColor = parseColorString(
                        tr.color, defaultTrendColor, successColor, destructiveColor, warningColor, primaryColor
                    )
                    val arrow = if (tr.direction == "up") "▲ " else if (tr.direction == "down") "▼ " else ""
                    val text = tr.percent_formatted ?: "${tr.percent}%"

                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = "$arrow$text",
                            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                            color = trendColor
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

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
                NetWorthLineChartCanvas(
                    series = series,
                    lineColor = primaryColor,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(140.dp)
                )
            }
        }
    }
}

@Composable
private fun NetWorthLineChartCanvas(
    series: List<NetWorthSeriesPointDto>,
    lineColor: Color,
    modifier: Modifier = Modifier
) {
    val minVal = series.minOf { it.value }
    val maxVal = series.maxOf { it.value }
    val range = (maxVal - minVal).let { if (it == 0.0) 1.0 else it }

    Box(modifier = modifier) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val widthPx = size.width
            val heightPx = size.height
            val paddingY = 16.dp.toPx()
            val drawHeight = heightPx - 2 * paddingY

            val points = series.mapIndexed { idx, item ->
                val x = (idx.toFloat() / (series.size - 1)) * widthPx
                val y = heightPx - paddingY - (((item.value - minVal) / range) * drawHeight).toFloat()
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
