package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.Canvas
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.screens.DonutSegmentUiModel
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.ButtonVariant
import py.com.cdco.financespy.utils.formatMoney

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
    initialized: Boolean,
    sourceBudgetName: String?,
    availableToAllocate: Double,
    segments: List<DonutSegmentUiModel>,
    actualSpending: Double,
    budgetedSpending: Double,
    currency: String,
    onCopyPrevious: () -> Unit,
    onStartFromScratch: () -> Unit,
    onFixAllocations: () -> Unit,
    modifier: Modifier = Modifier
) {
    AppCard(modifier = modifier.fillMaxWidth()) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            contentAlignment = Alignment.Center
        ) {
            when {
                !initialized && sourceBudgetName != null -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
                    ) {
                        Text(
                            text = "Configurá tu presupuesto",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary(),
                            textAlign = TextAlign.Center
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Podés copiar tu presupuesto desde $sourceBudgetName o empezar desde cero.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textSecondary(),
                            textAlign = TextAlign.Center
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
                            if (maxWidth < 640.dp) {
                                Column(
                                    verticalArrangement = Arrangement.spacedBy(8.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    AppButton(
                                        text = "Copiar desde $sourceBudgetName",
                                        onClick = onCopyPrevious,
                                        variant = ButtonVariant.Primary,
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                    AppButton(
                                        text = "Empezar desde cero",
                                        onClick = onStartFromScratch,
                                        variant = ButtonVariant.Secondary,
                                        modifier = Modifier.fillMaxWidth()
                                    )
                                }
                            } else {
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    AppButton(
                                        text = "Copiar desde $sourceBudgetName",
                                        onClick = onCopyPrevious,
                                        variant = ButtonVariant.Primary
                                    )
                                    AppButton(
                                        text = "Empezar desde cero",
                                        onClick = onStartFromScratch,
                                        variant = ButtonVariant.Secondary
                                    )
                                }
                            }
                        }
                    }
                }

                initialized && availableToAllocate < 0 -> {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                        modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.Warning,
                            contentDescription = "Advertencia",
                            tint = FinancePyColors.destructive(),
                            modifier = Modifier.size(36.dp)
                        )
                        Spacer(modifier = Modifier.height(8.dp))
                        Text(
                            text = "Superaste el presupuesto por ${formatMoney(-availableToAllocate, currency)}",
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.destructive(),
                            textAlign = TextAlign.Center
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = "Corregí las asignaciones para volver a equilibrar tu presupuesto.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textSecondary(),
                            textAlign = TextAlign.Center
                        )
                        Spacer(modifier = Modifier.height(16.dp))
                        AppButton(
                            text = "Corregir asignaciones",
                            onClick = onFixAllocations,
                            variant = ButtonVariant.Primary
                        )
                    }
                }

                else -> {
                    val totalAmount = segments.sumOf { it.amount }

                    Box(
                        modifier = Modifier.size(220.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Canvas(modifier = Modifier.fillMaxSize().padding(12.dp)) {
                            val strokeWidth = 22.dp.toPx()
                            if (totalAmount <= 0) {
                                drawArc(
                                    color = Color.LightGray.copy(alpha = 0.4f),
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
                                text = "Gastado",
                                style = MaterialTheme.typography.labelMedium,
                                color = FinancePyColors.textSecondary()
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = formatMoney(actualSpending, currency),
                                style = MaterialTheme.typography.headlineMedium.copy(fontWeight = FontWeight.Bold),
                                color = if (actualSpending > budgetedSpending && budgetedSpending > 0) {
                                    FinancePyColors.destructive()
                                } else {
                                    FinancePyColors.textPrimary()
                                }
                            )
                            Spacer(modifier = Modifier.height(2.dp))
                            Text(
                                text = if (budgetedSpending > 0) "de ${formatMoney(budgetedSpending, currency)}" else "Nuevo presupuesto",
                                style = MaterialTheme.typography.bodySmall,
                                color = FinancePyColors.textSecondary()
                            )
                        }
                    }
                }
            }
        }
    }
}
