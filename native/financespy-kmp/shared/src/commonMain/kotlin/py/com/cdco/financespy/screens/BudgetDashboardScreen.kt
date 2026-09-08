package py.com.cdco.financespy.screens

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import py.com.cdco.financespy.screens.components.BudgetCategoryDetailSheet
import py.com.cdco.financespy.screens.components.BudgetCategoryProgressItem
import py.com.cdco.financespy.screens.components.BudgetDonutChart
import py.com.cdco.financespy.screens.components.BudgetMonthNavigator
import py.com.cdco.financespy.screens.components.BudgetSummaryCard
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.components.AppButton
import py.com.cdco.financespy.theme.components.AppCard
import py.com.cdco.financespy.theme.components.ButtonVariant

@Composable
fun BudgetDashboardScreen(
    viewModel: BudgetDashboardViewModel,
    onNavigateToEditor: (budgetId: String) -> Unit = {},
    onNavigateToCategoryTransactions: (categoryId: String, startDate: String, endDate: String) -> Unit = { _, _, _ -> },
    modifier: Modifier = Modifier
) {
    val uiState by viewModel.uiState.collectAsState()

    Column(
        modifier = modifier.fillMaxSize().padding(16.dp)
    ) {
        BudgetMonthNavigator(
            year = uiState.year,
            month = uiState.month,
            budgetName = uiState.budgetName,
            onPreviousMonth = { viewModel.selectPreviousMonth() },
            onNextMonth = { viewModel.selectNextMonth() },
            onJumpToToday = { viewModel.jumpToToday() },
            onSelectMonthYear = { y, m -> viewModel.selectMonth(y, m) }
        )

        Spacer(modifier = Modifier.height(12.dp))

        if (uiState.isLoading) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = FinancePyColors.textPrimary())
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Responsive Top Block: Donut + Summary
                item {
                    val showSummaryTabs = uiState.initialized && uiState.availableToAllocate > 0
                    BoxWithConstraints(modifier = Modifier.fillMaxWidth()) {
                        if (maxWidth < 640.dp) {
                            Column(
                                verticalArrangement = Arrangement.spacedBy(16.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                BudgetDonutChart(
                                    initialized = uiState.initialized,
                                    sourceBudgetName = uiState.sourceBudgetName,
                                    availableToAllocate = uiState.availableToAllocate,
                                    segments = uiState.donutSegments,
                                    actualSpending = uiState.actualSpending,
                                    budgetedSpending = uiState.budgetedSpending,
                                    currency = uiState.currency,
                                    onCopyPrevious = { viewModel.copyPreviousBudget() },
                                    onStartFromScratch = { viewModel.startFromScratch() },
                                    onFixAllocations = {
                                        uiState.budgetId?.let { onNavigateToEditor(it) }
                                    }
                                )

                                BudgetSummaryCard(
                                    showTabs = showSummaryTabs,
                                    activeTab = uiState.activeTab,
                                    onTabSelected = { viewModel.setTab(it) },
                                    expectedIncome = uiState.expectedIncome,
                                    budgetedSpending = uiState.budgetedSpending,
                                    allocatedSpending = uiState.allocatedSpending,
                                    availableToAllocate = uiState.availableToAllocate,
                                    allocatedPercent = uiState.allocatedPercent,
                                    actualIncome = uiState.actualIncome,
                                    actualIncomePercent = uiState.actualIncomePercent,
                                    actualSpending = uiState.actualSpending,
                                    percentOfBudgetSpent = uiState.percentOfBudgetSpent,
                                    availableToSpend = uiState.availableToSpend,
                                    currency = uiState.currency
                                )
                            }
                        } else {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(16.dp),
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Box(modifier = Modifier.weight(1f)) {
                                    BudgetDonutChart(
                                        initialized = uiState.initialized,
                                        sourceBudgetName = uiState.sourceBudgetName,
                                        availableToAllocate = uiState.availableToAllocate,
                                        segments = uiState.donutSegments,
                                        actualSpending = uiState.actualSpending,
                                        budgetedSpending = uiState.budgetedSpending,
                                        currency = uiState.currency,
                                        onCopyPrevious = { viewModel.copyPreviousBudget() },
                                        onStartFromScratch = { viewModel.startFromScratch() },
                                        onFixAllocations = {
                                            uiState.budgetId?.let { onNavigateToEditor(it) }
                                        }
                                    )
                                }

                                Box(modifier = Modifier.weight(1f)) {
                                    BudgetSummaryCard(
                                        showTabs = showSummaryTabs,
                                        activeTab = uiState.activeTab,
                                        onTabSelected = { viewModel.setTab(it) },
                                        expectedIncome = uiState.expectedIncome,
                                        budgetedSpending = uiState.budgetedSpending,
                                        allocatedSpending = uiState.allocatedSpending,
                                        availableToAllocate = uiState.availableToAllocate,
                                        allocatedPercent = uiState.allocatedPercent,
                                        actualIncome = uiState.actualIncome,
                                        actualIncomePercent = uiState.actualIncomePercent,
                                        actualSpending = uiState.actualSpending,
                                        percentOfBudgetSpent = uiState.percentOfBudgetSpent,
                                        availableToSpend = uiState.availableToSpend,
                                        currency = uiState.currency
                                    )
                                }
                            }
                        }
                    }
                }

                // Categories Section Header
                item {
                    AppCard(modifier = Modifier.fillMaxWidth()) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        text = "Categorías",
                                        style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                                        color = FinancePyColors.textPrimary()
                                    )
                                    Spacer(modifier = Modifier.padding(horizontal = 4.dp))
                                    Text(
                                        text = "(${uiState.categories.size})",
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = FinancePyColors.textSecondary()
                                    )
                                }

                                if (uiState.initialized && uiState.budgetId != null) {
                                    AppButton(
                                        text = "Editar",
                                        onClick = { onNavigateToEditor(uiState.budgetId!!) },
                                        variant = ButtonVariant.Secondary
                                    )
                                }
                            }

                            if (uiState.hasOverBudgetCategories) {
                                Spacer(modifier = Modifier.height(12.dp))
                                TabRow(
                                    selectedTabIndex = when (uiState.categoryFilterTab) {
                                        "over_budget" -> 1
                                        "on_track" -> 2
                                        else -> 0
                                    },
                                    containerColor = FinancePyColors.container(),
                                    contentColor = FinancePyColors.textPrimary()
                                ) {
                                    Tab(
                                        selected = uiState.categoryFilterTab == "all",
                                        onClick = { viewModel.setCategoryFilterTab("all") },
                                        text = { Text("Todas") }
                                    )
                                    Tab(
                                        selected = uiState.categoryFilterTab == "over_budget",
                                        onClick = { viewModel.setCategoryFilterTab("over_budget") },
                                        text = { Text("Sobre presupuesto") }
                                    )
                                    Tab(
                                        selected = uiState.categoryFilterTab == "on_track",
                                        onClick = { viewModel.setCategoryFilterTab("on_track") },
                                        text = { Text("En camino") }
                                    )
                                }
                            }
                        }
                    }
                }

                // Categories List (Grouped by Parent)
                val filteredGroups = uiState.categoryGroups.mapNotNull { group ->
                    val filteredSubs = group.subcategories.filter { cat ->
                        when (uiState.categoryFilterTab) {
                            "over_budget" -> cat.status == BudgetCategoryStatus.OVER_BUDGET
                            "on_track" -> cat.status == BudgetCategoryStatus.ON_TRACK
                            else -> true
                        }
                    }
                    val parentMatches = when (uiState.categoryFilterTab) {
                        "over_budget" -> group.parentCategory.status == BudgetCategoryStatus.OVER_BUDGET
                        "on_track" -> group.parentCategory.status == BudgetCategoryStatus.ON_TRACK
                        else -> true
                    }

                    if (parentMatches || filteredSubs.isNotEmpty()) {
                        group.copy(subcategories = filteredSubs)
                    } else {
                        null
                    }
                }

                if (filteredGroups.isEmpty()) {
                    item {
                        Text(
                            text = "No hay categorías disponibles para este filtro.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = FinancePyColors.textSecondary(),
                            modifier = Modifier.padding(16.dp)
                        )
                    }
                } else {
                    filteredGroups.forEach { group ->
                        item(key = "parent_${group.parentCategory.id}") {
                            BudgetCategoryProgressItem(
                                category = group.parentCategory,
                                currency = uiState.currency,
                                onClick = { viewModel.selectCategory(group.parentCategory) }
                            )
                        }
                        items(group.subcategories, key = { "sub_${it.id}" }) { sub ->
                            BudgetCategoryProgressItem(
                                category = sub,
                                currency = uiState.currency,
                                onClick = { viewModel.selectCategory(sub) }
                            )
                        }
                    }
                }
            }
        }

        // Category Detail Bottom Sheet / Modal
        if (uiState.selectedCategory != null) {
            val cat = uiState.selectedCategory!!
            val monthStr = if (uiState.month < 10) "0${uiState.month}" else "${uiState.month}"
            val startDate = "${uiState.year}-$monthStr-01"
            val endDate = "${uiState.year}-$monthStr-31"

            BudgetCategoryDetailSheet(
                category = cat,
                currency = uiState.currency,
                recentTransactions = uiState.selectedCategoryRecentTransactions,
                isLoadingTransactions = uiState.isLoadingCategoryTransactions,
                onDismiss = { viewModel.selectCategory(null) },
                onViewAllTransactions = {
                    viewModel.selectCategory(null)
                    onNavigateToCategoryTransactions(cat.categoryId, startDate, endDate)
                }
            )
        }
    }
}
