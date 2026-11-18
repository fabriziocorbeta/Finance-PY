package py.com.cdco.financespy.screens

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
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.utils.formatPercent

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HoldingDetailScreen(
    viewModel: HoldingDetailViewModel,
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsState()

    LaunchedEffect(Unit) {
        viewModel.refresh()
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(state.ticker, style = MaterialTheme.typography.titleLarge) },
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
                state.isLoading && state.fullHistory.isEmpty() -> {
                    CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
                }
                state.error != null && state.fullHistory.isEmpty() -> {
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
                else -> {
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(16.dp)
                    ) {
                        Text(
                            text = state.name,
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textSecondary()
                        )

                        Spacer(modifier = Modifier.height(8.dp))

                        val changePct = state.periodChangePct
                        val isPositive = (changePct ?: 0.0) >= 0
                        val changeColor = if (isPositive) FinancePyColors.success() else FinancePyColors.destructive()

                        Text(
                            text = formatPriceAmount(state.currentPrice, state.currency),
                            style = MaterialTheme.typography.displaySmall.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary()
                        )

                        changePct?.let { pct ->
                            val arrow = if (pct >= 0) "▲" else "▼"
                            Text(
                                text = "$arrow ${formatPercent(kotlin.math.abs(pct))} (${state.selectedRange.label})",
                                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                color = changeColor
                            )
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        AppCard(modifier = Modifier.fillMaxWidth()) {
                            Column(modifier = Modifier.padding(16.dp)) {
                                if (state.visibleHistory.size < 2) {
                                    Box(
                                        modifier = Modifier.fillMaxWidth().height(200.dp),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            text = "No hay suficiente historial de precios",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = FinancePyColors.textSecondary()
                                        )
                                    }
                                } else {
                                    PriceLineChart(
                                        points = state.visibleHistory,
                                        lineColor = changeColor,
                                        modifier = Modifier.fillMaxWidth().height(200.dp)
                                    )
                                }

                                Spacer(modifier = Modifier.height(16.dp))

                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    PriceRange.entries.forEach { range ->
                                        val selected = range == state.selectedRange
                                        Surface(
                                            shape = RoundedCornerShape(16.dp),
                                            color = if (selected) FinancePyColors.buttonBgPrimary() else FinancePyColors.container(),
                                            modifier = Modifier.clickable { viewModel.selectRange(range) }
                                        ) {
                                            Text(
                                                text = range.label,
                                                style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.SemiBold),
                                                color = if (selected) FinancePyColors.surface() else FinancePyColors.textSecondary(),
                                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp)
                                            )
                                        }
                                    }
                                }
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Column {
                                Text("Máximo del período", style = MaterialTheme.typography.labelSmall, color = FinancePyColors.textSecondary())
                                Text(
                                    text = formatPriceAmount(state.periodHigh, state.currency),
                                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                    color = FinancePyColors.textPrimary()
                                )
                            }
                            Column(horizontalAlignment = Alignment.End) {
                                Text("Mínimo del período", style = MaterialTheme.typography.labelSmall, color = FinancePyColors.textSecondary())
                                Text(
                                    text = formatPriceAmount(state.periodLow, state.currency),
                                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold),
                                    color = FinancePyColors.textPrimary()
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun formatPriceAmount(value: Double?, currency: String): String {
    if (value == null) return "--"
    val formatted = (kotlin.math.round(value * 100) / 100)
    return "$formatted $currency"
}

@Composable
private fun PriceLineChart(
    points: List<PricePoint>,
    lineColor: Color,
    modifier: Modifier = Modifier
) {
    val minVal = points.minOf { it.price }
    val maxVal = points.maxOf { it.price }.let { if (it == minVal) it + 1.0 else it }

    Canvas(modifier = modifier) {
        val widthPx = size.width
        val heightPx = size.height
        val stepX = if (points.size > 1) widthPx / (points.size - 1) else widthPx

        fun yFor(price: Double): Float {
            val ratio = (price - minVal) / (maxVal - minVal)
            return (heightPx - (ratio * heightPx)).toFloat()
        }

        val linePath = Path()
        val fillPath = Path()
        points.forEachIndexed { idx, point ->
            val x = idx * stepX
            val y = yFor(point.price)
            if (idx == 0) {
                linePath.moveTo(x, y)
                fillPath.moveTo(x, heightPx)
                fillPath.lineTo(x, y)
            } else {
                linePath.lineTo(x, y)
                fillPath.lineTo(x, y)
            }
        }
        fillPath.lineTo((points.size - 1) * stepX, heightPx)
        fillPath.close()

        drawPath(path = fillPath, color = lineColor.copy(alpha = 0.12f), style = Fill)
        drawPath(path = linePath, color = lineColor, style = Stroke(width = 3.dp.toPx()))
    }
}
