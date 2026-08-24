package py.com.cdco.financespy.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard

fun formatBudgetPeriod(startDate: String): String {
    val parts = startDate.split("-")
    if (parts.size < 2) return startDate
    val year = parts[0]
    val monthNum = parts[1].toIntOrNull() ?: return startDate
    val months = listOf(
        "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
        "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
    )
    val monthName = months.getOrNull(monthNum - 1) ?: return startDate
    return "$monthName $year"
}

@Composable
fun BudgetsListScreen(
    viewModel: BudgetsListViewModel,
    onBudgetClick: (String) -> Unit,
    onCreateClick: () -> Unit
) {
    val budgets by viewModel.budgets.collectAsState()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(FinancePyColors.surface())
    ) {
        LazyColumn(
            modifier = Modifier.fillMaxSize(),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                AppButton(
                    text = "Nuevo presupuesto",
                    onClick = onCreateClick,
                    modifier = Modifier.fillMaxWidth()
                )
            }

            items(budgets) { budget ->
                val isOverBudget = budget.percentOfBudgetSpent > 100.0
                val progressFraction = (budget.percentOfBudgetSpent / 100.0).coerceIn(0.0, 1.0).toFloat()

                AppCard(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onBudgetClick(budget.id) }
                ) {
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = formatBudgetPeriod(budget.startDate),
                                style = MaterialTheme.typography.titleMedium,
                                color = FinancePyColors.textPrimary()
                            )
                            Text(
                                text = "${budget.percentOfBudgetSpent}%",
                                style = MaterialTheme.typography.labelMedium,
                                color = if (isOverBudget) FinancePyColors.destructive() else FinancePyColors.textSecondary()
                            )
                        }

                        LinearProgressIndicator(
                            progress = { progressFraction },
                            modifier = Modifier.fillMaxWidth(),
                            color = if (isOverBudget) FinancePyColors.destructive() else FinancePyColors.textPrimary(),
                            trackColor = FinancePyColors.container()
                        )

                        Text(
                            text = "${budget.actualSpending} / ${budget.budgetedSpending} ${budget.currency}",
                            style = MaterialTheme.typography.bodyMedium,
                            color = if (isOverBudget) FinancePyColors.destructive() else FinancePyColors.textSecondary()
                        )
                    }
                }
            }
        }
    }
}
