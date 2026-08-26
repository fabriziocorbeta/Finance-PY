package py.com.cdco.financespy.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.screens.components.BudgetCategoryProgressItem
import py.com.cdco.financespy.screens.components.BudgetDonutChart
import py.com.cdco.financespy.screens.components.BudgetMonthNavigator
import py.com.cdco.financespy.screens.components.BudgetSummaryCard

@Composable
fun BudgetDashboardScreen(
    viewModel: BudgetDashboardViewModel,
    modifier: Modifier = Modifier
) {
    val uiState by viewModel.uiState.collectAsState()

    Column(
        modifier = modifier.fillMaxSize().padding(16.dp)
    ) {
        BudgetMonthNavigator(
            year = uiState.year,
            month = uiState.month,
            onPreviousMonth = { viewModel.selectPreviousMonth() },
            onNextMonth = { viewModel.selectNextMonth() }
        )

        Spacer(modifier = Modifier.height(12.dp))

        if (uiState.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                item {
                    Box(
                        modifier = Modifier.fillMaxWidth(),
                        contentAlignment = Alignment.Center
                    ) {
                        BudgetDonutChart(
                            segments = uiState.donutSegments,
                            actualSpending = uiState.actualSpending,
                            budgetedSpending = uiState.budgetedSpending,
                            currency = uiState.currency
                        )
                    }
                }

                item {
                    BudgetSummaryCard(
                        activeTab = uiState.activeTab,
                        onTabSelected = { viewModel.setTab(it) },
                        budgetedSpending = uiState.budgetedSpending,
                        actualSpending = uiState.actualSpending,
                        availableToSpend = uiState.availableToSpend,
                        expectedIncome = uiState.expectedIncome,
                        currency = uiState.currency
                    )
                }

                item {
                    Text(
                        text = "Categories",
                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }

                if (uiState.categories.isEmpty()) {
                    item {
                        Text(
                            text = "No category budget details available for this month.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                } else {
                    items(uiState.categories, key = { it.id }) { category ->
                        BudgetCategoryProgressItem(
                            category = category,
                            currency = uiState.currency
                        )
                    }
                }
            }
        }
    }
}
