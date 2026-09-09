package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
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
import py.com.cdco.financespy.api.dto.DonutCategoryDto
import py.com.cdco.financespy.api.dto.OutflowsDonutDto
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.utils.formatMoney

@Composable
fun OutflowsDonutCard(
    outflowsDonut: OutflowsDonutDto?,
    onCategoryClick: (DonutCategoryDto) -> Unit = {},
    modifier: Modifier = Modifier
) {
    AppCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Salidas",
                style = MaterialTheme.typography.titleMedium,
                color = FinancePyColors.textPrimary()
            )

            val categories = outflowsDonut?.categories ?: emptyList()
            val total = outflowsDonut?.total ?: 0.0
            val currencySymbol = outflowsDonut?.currency_symbol ?: outflowsDonut?.currency ?: "₲"

            val successColor = FinancePyColors.success()
            val destructiveColor = FinancePyColors.destructive()
            val warningColor = FinancePyColors.warning()
            val primaryColor = FinancePyColors.buttonBgPrimary()
            val borderSecondaryColor = FinancePyColors.borderSecondary()

            Spacer(modifier = Modifier.height(16.dp))

            Column(
                modifier = Modifier.fillMaxWidth(),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Box(
                    modifier = Modifier.size(200.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Canvas(modifier = Modifier.fillMaxSize().padding(12.dp)) {
                        val strokeWidth = 20.dp.toPx()
                        if (total <= 0 || categories.isEmpty()) {
                            drawArc(
                                color = borderSecondaryColor,
                                startAngle = 0f,
                                sweepAngle = 360f,
                                useCenter = false,
                                style = Stroke(width = strokeWidth)
                            )
                        } else {
                            var startAngle = -90f
                            categories.forEach { cat ->
                                val sweepAngle = ((cat.amount / total) * 360f).toFloat()
                                val color = parseColorString(
                                    cat.color, primaryColor, successColor, destructiveColor, warningColor, primaryColor
                                )
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

                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = "Total",
                            style = MaterialTheme.typography.labelSmall,
                            color = FinancePyColors.textSecondary()
                        )
                        Text(
                            text = formatMoney(total, currencySymbol),
                            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                            color = FinancePyColors.textPrimary()
                        )
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                Column(
                    modifier = Modifier.fillMaxWidth(),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    categories.forEach { cat ->
                        OutflowCategoryRow(
                            category = cat,
                            currencySymbol = currencySymbol,
                            successColor = successColor,
                            destructiveColor = destructiveColor,
                            warningColor = warningColor,
                            primaryColor = primaryColor,
                            onClick = { if (cat.clickable) onCategoryClick(cat) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun OutflowCategoryRow(
    category: DonutCategoryDto,
    currencySymbol: String,
    successColor: Color,
    destructiveColor: Color,
    warningColor: Color,
    primaryColor: Color,
    onClick: () -> Unit
) {
    val catColor = parseColorString(
        category.color, primaryColor, successColor, destructiveColor, warningColor, primaryColor
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(enabled = category.clickable, onClick = onClick)
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.weight(1f)
        ) {
            Box(
                modifier = Modifier
                    .size(10.dp)
                    .background(catColor, CircleShape)
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = category.name,
                style = MaterialTheme.typography.bodyMedium,
                color = FinancePyColors.textPrimary()
            )
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = formatMoney(category.amount, currencySymbol),
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                color = FinancePyColors.textPrimary()
            )
            category.percentage?.let { pct ->
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "${pct}%",
                    style = MaterialTheme.typography.bodySmall,
                    color = FinancePyColors.textSecondary()
                )
            }
        }
    }
}
