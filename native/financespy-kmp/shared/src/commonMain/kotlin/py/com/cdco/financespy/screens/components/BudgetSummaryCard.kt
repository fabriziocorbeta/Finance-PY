package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppCard

@Composable
fun BudgetSummaryCard(
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
    modifier: Modifier = Modifier
) {
    AppCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
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

            if (activeTab == "budgeted") {
                SummaryRow(
                    label = "Ingreso esperado",
                    amountText = "$currency ${expectedIncome.toInt()}"
                )
                SummaryRow(
                    label = "Presupuestado",
                    amountText = "$currency ${budgetedSpending.toInt()}"
                )

                Spacer(modifier = Modifier.height(12.dp))

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

                Spacer(modifier = Modifier.height(12.dp))

                SummaryRow(
                    label = "Disponible para asignar",
                    amountText = "$currency ${availableToAllocate.toInt()}",
                    isHighlight = true,
                    isNegativeWarning = availableToAllocate < 0
                )
            } else {
                SummaryRow(
                    label = "Ingreso real",
                    amountText = "$currency ${actualIncome.toInt()}",
                    subtitle = if (expectedIncome > 0) "${actualIncomePercent.toInt()}% del esperado" else null
                )
                SummaryRow(
                    label = "Gasto real",
                    amountText = "$currency ${actualSpending.toInt()}",
                    subtitle = if (budgetedSpending > 0) "${percentOfBudgetSpent.toInt()}% del presupuestado" else null
                )

                Spacer(modifier = Modifier.height(12.dp))

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

                Spacer(modifier = Modifier.height(12.dp))

                SummaryRow(
                    label = if (availableToSpend < 0) "Sobre presupuesto" else "Disponible",
                    amountText = "$currency ${availableToSpend.toInt()}",
                    isHighlight = true,
                    isNegativeWarning = availableToSpend < 0
                )
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
