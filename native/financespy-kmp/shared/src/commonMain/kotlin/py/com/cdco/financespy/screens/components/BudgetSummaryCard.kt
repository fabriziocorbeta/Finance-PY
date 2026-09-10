package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.screens.BudgetCategoryUiModel
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.utils.formatMoney

@Composable
fun BudgetSummaryCard(
    showTabs: Boolean = true,
    activeTab: String,
    onTabSelected: (String) -> Unit,
    expectedIncome: Double,
    budgetedSpending: Double,
    allocatedSpending: Double,
    availableToAllocate: Double,
    allocatedPercent: Double,
    actualIncome: Double,
    actualIncomePercent: Double,
    actualSpending: Double,
    percentOfBudgetSpent: Double,
    availableToSpend: Double,
    currency: String,
    categories: List<BudgetCategoryUiModel> = emptyList(),
    modifier: Modifier = Modifier
) {
    AppCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            if (showTabs) {
                TabRow(
                    selectedTabIndex = if (activeTab == "budgeted") 0 else 1,
                    containerColor = FinancePyColors.container(),
                    contentColor = FinancePyColors.textPrimary()
                ) {
                    Tab(
                        selected = activeTab == "budgeted",
                        onClick = { onTabSelected("budgeted") },
                        text = {
                            Text(
                                "Presupuestado",
                                style = MaterialTheme.typography.labelLarge,
                                color = if (activeTab == "budgeted") FinancePyColors.textPrimary() else FinancePyColors.textSecondary()
                            )
                        }
                    )
                    Tab(
                        selected = activeTab == "actuals",
                        onClick = { onTabSelected("actuals") },
                        text = {
                            Text(
                                "Real",
                                style = MaterialTheme.typography.labelLarge,
                                color = if (activeTab == "actuals") FinancePyColors.textPrimary() else FinancePyColors.textSecondary()
                            )
                        }
                    )
                }

                Spacer(modifier = Modifier.height(16.dp))
            }

            if (showTabs && activeTab == "budgeted") {
                SummaryRow(
                    label = "Ingreso esperado",
                    amountText = formatMoney(expectedIncome, currency)
                )
                SummaryRow(
                    label = "Presupuestado",
                    amountText = formatMoney(budgetedSpending, currency)
                )

                Spacer(modifier = Modifier.height(12.dp))

                val budgetedSegments = categories
                    .filter { !it.isSubcategory && it.budgetedSpending > 0 }
                    .map { parseHexColor(it.color) to it.budgetedSpending.toFloat() }

                if (budgetedSegments.isNotEmpty()) {
                    MultiSegmentProgressBar(segments = budgetedSegments)
                } else {
                    val progressFraction = (allocatedPercent / 100.0).toFloat().coerceIn(0f, 1f)
                    LinearProgressIndicator(
                        progress = { progressFraction },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(8.dp)
                            .clip(RoundedCornerShape(4.dp)),
                        color = if (availableToAllocate < 0) FinancePyColors.destructive() else FinancePyColors.buttonBgPrimary(),
                        trackColor = FinancePyColors.borderSecondary()
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))

                SummaryRow(
                    label = if (availableToAllocate < 0) "Superaste el presupuesto por" else "Disponible para asignar",
                    amountText = formatMoney(if (availableToAllocate < 0) -availableToAllocate else availableToAllocate, currency),
                    isHighlight = true,
                    isNegativeWarning = availableToAllocate < 0
                )
            } else {
                SummaryRow(
                    label = "Ingresos",
                    amountText = formatMoney(actualIncome, currency),
                    subtitle = if (expectedIncome > 0) "${actualIncomePercent.toInt()}% del esperado" else null
                )
                SummaryRow(
                    label = "Gastos",
                    amountText = formatMoney(actualSpending, currency),
                    subtitle = if (budgetedSpending > 0) "${percentOfBudgetSpent.toInt()}% del presupuestado" else null
                )

                Spacer(modifier = Modifier.height(12.dp))

                val actualSegments = categories
                    .filter { !it.isSubcategory && it.actualSpending > 0 }
                    .map { parseHexColor(it.color) to it.actualSpending.toFloat() }

                if (actualSegments.isNotEmpty()) {
                    MultiSegmentProgressBar(segments = actualSegments)
                } else {
                    val spentFraction = if (budgetedSpending > 0) {
                        (actualSpending / budgetedSpending).toFloat().coerceIn(0f, 1f)
                    } else 0f

                    LinearProgressIndicator(
                        progress = { spentFraction },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(8.dp)
                            .clip(RoundedCornerShape(4.dp)),
                        color = if (actualSpending > budgetedSpending && budgetedSpending > 0) {
                            FinancePyColors.destructive()
                        } else {
                            FinancePyColors.success()
                        },
                        trackColor = FinancePyColors.borderSecondary()
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))

                SummaryRow(
                    label = if (availableToSpend < 0) "Sobre presupuesto" else "Disponible",
                    amountText = formatMoney(availableToSpend, currency),
                    isHighlight = true,
                    isNegativeWarning = availableToSpend < 0
                )
            }
        }
    }
}

@Composable
private fun MultiSegmentProgressBar(
    segments: List<Pair<Color, Float>>,
    modifier: Modifier = Modifier
) {
    val totalWeight = segments.sumOf { it.second.toDouble() }.toFloat()
    if (totalWeight <= 0f) {
        Box(
            modifier = modifier
                .fillMaxWidth()
                .height(8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(FinancePyColors.borderSecondary())
        )
    } else {
        Row(
            modifier = modifier
                .fillMaxWidth()
                .height(8.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(FinancePyColors.borderSecondary())
        ) {
            segments.forEach { (color, weight) ->
                if (weight > 0f) {
                    Box(
                        modifier = Modifier
                            .weight(weight / totalWeight)
                            .height(8.dp)
                            .background(color)
                    )
                }
            }
        }
    }
}

@Composable
private fun SummaryRow(
    label: String,
    amountText: String,
    subtitle: String? = null,
    isHighlight: Boolean = false,
    isNegativeWarning: Boolean = false
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column {
            Text(
                text = label,
                style = if (isHighlight) MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold)
                        else MaterialTheme.typography.bodyMedium,
                color = FinancePyColors.textSecondary()
            )
            if (subtitle != null) {
                Text(
                    text = subtitle,
                    style = MaterialTheme.typography.labelSmall,
                    color = FinancePyColors.textSecondary()
                )
            }
        }

        Text(
            text = amountText,
            style = if (isHighlight) MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Bold)
                    else MaterialTheme.typography.bodyMedium,
            color = when {
                isNegativeWarning -> FinancePyColors.destructive()
                isHighlight -> FinancePyColors.textPrimary()
                else -> FinancePyColors.textPrimary()
            }
        )
    }
}
