package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.screens.BudgetCategoryStatus
import py.com.cdco.financespy.screens.BudgetCategoryUiModel
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppCard

@Composable
fun BudgetCategoryProgressItem(
    category: BudgetCategoryUiModel,
    currency: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val categoryColor = parseHexColor(category.color)
    val startIndent = if (category.isSubcategory) 24.dp else 0.dp

    val progressFraction = (category.barWidthPercent / 100f).coerceIn(0f, 1f)
    val isOverBudget = category.status == BudgetCategoryStatus.OVER_BUDGET

    AppCard(
        modifier = modifier
            .fillMaxWidth()
            .padding(start = startIndent)
            .clickable { onClick() }
    ) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.weight(1f)
                ) {
                    if (category.isSubcategory) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                            contentDescription = "Subcategoría",
                            tint = FinancePyColors.textSecondary(),
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                    }

                    Box(
                        modifier = Modifier
                            .size(12.dp)
                            .clip(CircleShape)
                            .background(categoryColor)
                    )
                    Spacer(modifier = Modifier.width(8.dp))

                    Text(
                        text = category.name,
                        style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                        color = FinancePyColors.textPrimary()
                    )

                    Spacer(modifier = Modifier.width(8.dp))

                    // Status Badge
                    val (badgeBg, badgeFg, badgeText) = when (category.status) {
                        BudgetCategoryStatus.OVER_BUDGET -> Triple(FinancePyColors.destructive().copy(alpha = 0.15f), FinancePyColors.destructive(), "Sobre presupuesto")
                        BudgetCategoryStatus.NEAR_LIMIT -> Triple(FinancePyColors.warning().copy(alpha = 0.15f), FinancePyColors.warning(), "Alerta")
                        BudgetCategoryStatus.ON_TRACK -> Triple(FinancePyColors.success().copy(alpha = 0.15f), FinancePyColors.success(), "En camino")
                    }

                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(4.dp))
                            .background(badgeBg)
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    ) {
                        Text(
                            text = badgeText,
                            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                            color = badgeFg
                        )
                    }
                }

                Spacer(modifier = Modifier.width(8.dp))

                Text(
                    text = if (category.budgetedSpending > 0) {
                        "$currency ${category.actualSpending.toInt()} / ${category.budgetedSpending.toInt()}"
                    } else {
                        "$currency ${category.actualSpending.toInt()}"
                    },
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                    color = if (isOverBudget) FinancePyColors.destructive() else FinancePyColors.textSecondary()
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            LinearProgressIndicator(
                progress = { progressFraction },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(6.dp)
                    .clip(RoundedCornerShape(3.dp)),
                color = if (isOverBudget) FinancePyColors.destructive() else categoryColor,
                trackColor = categoryColor.copy(alpha = 0.2f)
            )

            Spacer(modifier = Modifier.height(6.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = category.statusAmountText,
                    style = MaterialTheme.typography.labelSmall,
                    color = if (isOverBudget) FinancePyColors.destructive() else FinancePyColors.textSecondary()
                )

                if (category.suggestedDailySpending != null) {
                    val daily = category.suggestedDailySpending
                    Text(
                        text = "$currency ${daily.amount.toInt()}/día (${daily.daysRemaining}d)",
                        style = MaterialTheme.typography.labelSmall,
                        color = FinancePyColors.textSecondary()
                    )
                }
            }
        }
    }
}
