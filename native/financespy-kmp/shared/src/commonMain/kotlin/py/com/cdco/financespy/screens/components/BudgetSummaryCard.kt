package py.com.cdco.financespy.screens.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.theme.components.AppCard

@Composable
fun BudgetSummaryCard(
    activeTab: String,
    onTabSelected: (String) -> Unit,
    budgetedSpending: Double,
    actualSpending: Double,
    availableToSpend: Double,
    expectedIncome: Double,
    currency: String,
    modifier: Modifier = Modifier
) {
    AppCard(modifier = modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            TabRow(
                selectedTabIndex = if (activeTab == "budgeted") 0 else 1
            ) {
                Tab(
                    selected = activeTab == "budgeted",
                    onClick = { onTabSelected("budgeted") },
                    text = { Text("Budgeted") }
                )
                Tab(
                    selected = activeTab == "actuals",
                    onClick = { onTabSelected("actuals") },
                    text = { Text("Actual") }
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            if (activeTab == "budgeted") {
                SummaryRow(label = "Budgeted Spending", amount = budgetedSpending, currency = currency)
                SummaryRow(label = "Expected Income", amount = expectedIncome, currency = currency)
                SummaryRow(
                    label = "Available to Spend",
                    amount = availableToSpend,
                    currency = currency,
                    isHighlight = true,
                    isNegativeWarning = availableToSpend < 0
                )
            } else {
                SummaryRow(label = "Actual Spending", amount = actualSpending, currency = currency)
                SummaryRow(
                    label = "Remaining Budget",
                    amount = availableToSpend,
                    currency = currency,
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
    amount: Double,
    currency: String,
    isHighlight: Boolean = false,
    isNegativeWarning: Boolean = false
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = label,
            style = if (isHighlight) MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Bold)
                    else MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = "$currency ${amount.toInt()}",
            style = if (isHighlight) MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Bold)
                    else MaterialTheme.typography.bodyMedium,
            color = when {
                isNegativeWarning -> MaterialTheme.colorScheme.error
                isHighlight -> MaterialTheme.colorScheme.primary
                else -> MaterialTheme.colorScheme.onSurface
            }
        )
    }
}
