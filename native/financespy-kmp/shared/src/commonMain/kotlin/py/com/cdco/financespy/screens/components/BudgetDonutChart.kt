package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.screens.DonutSegmentUiModel

fun parseHexColor(hex: String): Color {
    val cleanHex = hex.removePrefix("#")
    return try {
        when (cleanHex.length) {
            6 -> {
                val r = cleanHex.substring(0, 2).toInt(16)
                val g = cleanHex.substring(2, 4).toInt(16)
                val b = cleanHex.substring(4, 6).toInt(16)
                Color(r, g, b)
            }
            8 -> {
                val a = cleanHex.substring(0, 2).toInt(16)
                val r = cleanHex.substring(2, 4).toInt(16)
                val g = cleanHex.substring(4, 6).toInt(16)
                val b = cleanHex.substring(6, 8).toInt(16)
                Color(r, g, b, a)
            }
            else -> Color.Gray
        }
    } catch (_: Exception) {
        Color.Gray
    }
}

@Composable
fun BudgetDonutChart(
    segments: List<DonutSegmentUiModel>,
    actualSpending: Double,
    budgetedSpending: Double,
    currency: String,
    modifier: Modifier = Modifier
) {
    val totalAmount = segments.sumOf { it.amount }

    Box(
        modifier = modifier.size(240.dp),
        contentAlignment = Alignment.Center
    ) {
        Canvas(modifier = Modifier.fillMaxSize().padding(16.dp)) {
            val strokeWidth = 24.dp.toPx()
            if (totalAmount <= 0) {
                drawArc(
                    color = Color.LightGray.copy(alpha = 0.5f),
                    startAngle = 0f,
                    sweepAngle = 360f,
                    useCenter = false,
                    style = Stroke(width = strokeWidth)
                )
            } else {
                var startAngle = -90f
                segments.forEach { segment ->
                    val sweepAngle = ((segment.amount / totalAmount) * 360f).toFloat()
                    val color = parseHexColor(segment.color)
                    drawArc(
                        color = color,
                        startAngle = startAngle,
                        sweepAngle = sweepAngle,
                        useCenter = false,
                        style = Stroke(width = strokeWidth, cap = StrokeCap.Butt)
                    )
                    startAngle += sweepAngle
                }
            }
        }

        Column(
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "Spent",
                style = MaterialTheme.typography.labelMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = "$currency ${actualSpending.toInt()}",
                style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold),
                color = if (actualSpending > budgetedSpending && budgetedSpending > 0) {
                    MaterialTheme.colorScheme.error
                } else {
                    MaterialTheme.colorScheme.onSurface
                }
            )
            Text(
                text = "of $currency ${budgetedSpending.toInt()}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}
