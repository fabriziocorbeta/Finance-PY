package py.com.cdco.financespy

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ScrollableTabRow
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRowDefaults
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import py.com.cdco.financespy.navigation.Routes
import py.com.cdco.financespy.screens.AccountDetailScreen
import py.com.cdco.financespy.screens.AccountDetailViewModel
import py.com.cdco.financespy.screens.BudgetDashboardScreen
import py.com.cdco.financespy.screens.BudgetDashboardViewModel
import py.com.cdco.financespy.screens.DashboardScreen
import py.com.cdco.financespy.screens.DashboardViewModel
import py.com.cdco.financespy.screens.GoalDetailScreen
import py.com.cdco.financespy.screens.GoalDetailViewModel
import py.com.cdco.financespy.screens.GoalFormScreen
import py.com.cdco.financespy.screens.GoalFormViewModel
import py.com.cdco.financespy.screens.GoalsListScreen
import py.com.cdco.financespy.screens.GoalsListViewModel
import py.com.cdco.financespy.screens.LoginScreen
import py.com.cdco.financespy.screens.ReceivableDetailScreen
import py.com.cdco.financespy.screens.ReceivableDetailViewModel
import py.com.cdco.financespy.screens.ReceivableFormScreen
import py.com.cdco.financespy.screens.ReceivableFormViewModel
import py.com.cdco.financespy.screens.ReceivablesListScreen
import py.com.cdco.financespy.screens.ReceivablesListViewModel
import py.com.cdco.financespy.screens.RuleDetailScreen
import py.com.cdco.financespy.screens.RuleDetailViewModel
import py.com.cdco.financespy.screens.RuleFormScreen
import py.com.cdco.financespy.screens.RuleFormViewModel
import py.com.cdco.financespy.screens.RulesListScreen
import py.com.cdco.financespy.screens.RulesListViewModel
import py.com.cdco.financespy.screens.TransactionsScreen
import py.com.cdco.financespy.screens.TransactionsViewModel
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.FinancePyTheme

@Composable
fun App(
    isLoggedIn: Boolean?,
    onLoginClick: () -> Unit,
    dashboardViewModelFactory: () -> DashboardViewModel,
    budgetDashboardViewModelFactory: () -> BudgetDashboardViewModel,
    transactionsViewModelFactory: () -> TransactionsViewModel,
    rulesListViewModelFactory: () -> RulesListViewModel,
    ruleDetailViewModelFactory: (String) -> RuleDetailViewModel,
    ruleFormViewModelFactory: (String?) -> RuleFormViewModel,
    goalsListViewModelFactory: () -> GoalsListViewModel,
    goalDetailViewModelFactory: (String) -> GoalDetailViewModel,
    goalFormViewModelFactory: (String?) -> GoalFormViewModel,
    accountDetailViewModelFactory: (String) -> AccountDetailViewModel,
    receivablesListViewModelFactory: () -> ReceivablesListViewModel,
    receivableDetailViewModelFactory: (String) -> ReceivableDetailViewModel,
    receivableFormViewModelFactory: (String?) -> ReceivableFormViewModel
) {
    FinancePyTheme {
        if (isLoggedIn != null) {
            LaunchedEffect(Unit) {
                println("ColdStartProfile: FIRST FRAME RENDERED at ${System.currentTimeMillis()} ms")
            }
        }
        when (isLoggedIn) {
            null -> {}
            false -> LoginScreen(onLoginClick = onLoginClick)
            true -> {
                val navController = rememberNavController()
                val backStackEntry by navController.currentBackStackEntryAsState()
                val currentRoute = backStackEntry?.destination?.route

                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(FinancePyColors.surface())
                        .statusBarsPadding()
                        .navigationBarsPadding()
                ) {
                    if (currentRoute in listOf(Routes.DASHBOARD, Routes.BUDGETS, Routes.TRANSACTIONS, Routes.RULES, Routes.GOALS, Routes.RECEIVABLES)) {
                        val selectedIndex = when (currentRoute) {
                            Routes.BUDGETS -> 1
                            Routes.TRANSACTIONS -> 2
                            Routes.RULES -> 3
                            Routes.GOALS -> 4
                            Routes.RECEIVABLES -> 5
                            else -> 0
                        }
                        ScrollableTabRow(
                            selectedTabIndex = selectedIndex,
                            edgePadding = 0.dp,
                            containerColor = FinancePyColors.container(),
                            contentColor = FinancePyColors.textPrimary(),
                            indicator = { tabPositions ->
                                if (selectedIndex < tabPositions.size) {
                                    TabRowDefaults.SecondaryIndicator(
                                        Modifier.tabIndicatorOffset(tabPositions[selectedIndex]),
                                        color = FinancePyColors.textPrimary()
                                    )
                                }
                            }
                        ) {
                            Tab(
                                selected = currentRoute == Routes.DASHBOARD,
                                onClick = { navController.navigate(Routes.DASHBOARD) { launchSingleTop = true } },
                                text = {
                                    Text(
                                        "Dashboard",
                                        style = MaterialTheme.typography.labelLarge,
                                        color = if (currentRoute == Routes.DASHBOARD) FinancePyColors.textPrimary() else FinancePyColors.textSecondary(),
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            )
                            Tab(
                                selected = currentRoute == Routes.BUDGETS,
                                onClick = { navController.navigate(Routes.BUDGETS) { launchSingleTop = true } },
                                text = {
                                    Text(
                                        "Presupuestos",
                                        style = MaterialTheme.typography.labelLarge,
                                        color = if (currentRoute == Routes.BUDGETS) FinancePyColors.textPrimary() else FinancePyColors.textSecondary(),
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            )
                            Tab(
                                selected = currentRoute == Routes.TRANSACTIONS,
                                onClick = { navController.navigate(Routes.TRANSACTIONS) { launchSingleTop = true } },
                                text = {
                                    Text(
                                        "Transacciones",
                                        style = MaterialTheme.typography.labelLarge,
                                        color = if (currentRoute == Routes.TRANSACTIONS) FinancePyColors.textPrimary() else FinancePyColors.textSecondary(),
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            )
                            Tab(
                                selected = currentRoute == Routes.RULES,
                                onClick = { navController.navigate(Routes.RULES) { launchSingleTop = true } },
                                text = {
                                    Text(
                                        "Reglas",
                                        style = MaterialTheme.typography.labelLarge,
                                        color = if (currentRoute == Routes.RULES) FinancePyColors.textPrimary() else FinancePyColors.textSecondary(),
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            )
                            Tab(
                                selected = currentRoute == Routes.GOALS,
                                onClick = { navController.navigate(Routes.GOALS) { launchSingleTop = true } },
                                text = {
                                    Text(
                                        "Metas",
                                        style = MaterialTheme.typography.labelLarge,
                                        color = if (currentRoute == Routes.GOALS) FinancePyColors.textPrimary() else FinancePyColors.textSecondary(),
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            )
                            Tab(
                                selected = currentRoute == Routes.RECEIVABLES,
                                onClick = { navController.navigate(Routes.RECEIVABLES) { launchSingleTop = true } },
                                text = {
                                    Text(
                                        "Cuentas a cobrar",
                                        style = MaterialTheme.typography.labelLarge,
                                        color = if (currentRoute == Routes.RECEIVABLES) FinancePyColors.textPrimary() else FinancePyColors.textSecondary(),
                                        maxLines = 1,
                                        overflow = TextOverflow.Ellipsis
                                    )
                                }
                            )
                        }
                    }

                    NavHost(navController = navController, startDestination = Routes.DASHBOARD) {
                        composable(Routes.DASHBOARD) {
                            DashboardScreen(
                                viewModel = remember { dashboardViewModelFactory() },
                                onAccountClick = { accountId -> navController.navigate(Routes.accountDetail(accountId)) }
                            )
                        }
                        composable(Routes.BUDGETS) {
                            BudgetDashboardScreen(
                                viewModel = remember { budgetDashboardViewModelFactory() }
                            )
                        }
                        composable(Routes.TRANSACTIONS) {
                            TransactionsScreen(viewModel = remember { transactionsViewModelFactory() })
                        }
                        composable(Routes.RULES) {
                            RulesListScreen(
                                viewModel = remember { rulesListViewModelFactory() },
                                onRuleClick = { ruleId -> navController.navigate(Routes.ruleDetail(ruleId)) },
                                onCreateClick = { navController.navigate(Routes.ruleFormCreate()) }
                            )
                        }
                        composable(Routes.GOALS) {
                            GoalsListScreen(
                                viewModel = remember { goalsListViewModelFactory() },
                                onGoalClick = { goalId -> navController.navigate(Routes.goalDetail(goalId)) },
                                onCreateClick = { navController.navigate(Routes.goalFormCreate()) }
                            )
                        }
                        composable(Routes.RECEIVABLES) {
                            ReceivablesListScreen(
                                viewModel = remember { receivablesListViewModelFactory() },
                                onReceivableClick = { receivableId -> navController.navigate(Routes.receivableDetail(receivableId)) },
                                onCreateClick = { navController.navigate(Routes.receivableFormCreate()) }
                            )
                        }
                        composable(Routes.ACCOUNT_DETAIL) { entry ->
                            val accountId = entry.arguments?.getString("accountId") ?: return@composable
                            AccountDetailScreen(viewModel = remember(accountId) { accountDetailViewModelFactory(accountId) })
                        }
                        composable(Routes.RULE_DETAIL) { entry ->
                            val ruleId = entry.arguments?.getString("ruleId") ?: return@composable
                            RuleDetailScreen(
                                viewModel = remember(ruleId) { ruleDetailViewModelFactory(ruleId) },
                                onEditClick = { navController.navigate(Routes.ruleFormEdit(ruleId)) },
                                onDeleted = { navController.popBackStack(Routes.RULES, inclusive = false) }
                            )
                        }
                        composable(Routes.RULE_FORM) { entry ->
                            val ruleId = entry.arguments?.getString("ruleId")
                            RuleFormScreen(
                                viewModel = remember(ruleId) { ruleFormViewModelFactory(ruleId) },
                                onSaved = { navController.popBackStack() }
                            )
                        }
                        composable(Routes.GOAL_DETAIL) { entry ->
                            val goalId = entry.arguments?.getString("goalId") ?: return@composable
                            GoalDetailScreen(
                                viewModel = remember(goalId) { goalDetailViewModelFactory(goalId) },
                                onEditClick = { navController.navigate(Routes.goalFormEdit(goalId)) },
                                onDeleted = { navController.popBackStack(Routes.GOALS, inclusive = false) }
                            )
                        }
                        composable(Routes.GOAL_FORM) { entry ->
                            val goalId = entry.arguments?.getString("goalId")
                            GoalFormScreen(
                                viewModel = remember(goalId) { goalFormViewModelFactory(goalId) },
                                onSaved = { navController.popBackStack() }
                            )
                        }
                        composable(Routes.RECEIVABLE_DETAIL) { entry ->
                            val receivableId = entry.arguments?.getString("receivableId") ?: return@composable
                            ReceivableDetailScreen(
                                viewModel = remember(receivableId) { receivableDetailViewModelFactory(receivableId) },
                                onEditClick = { navController.navigate(Routes.receivableFormEdit(receivableId)) },
                                onDeleted = { navController.popBackStack(Routes.RECEIVABLES, inclusive = false) }
                            )
                        }
                        composable(Routes.RECEIVABLE_FORM) { entry ->
                            val receivableId = entry.arguments?.getString("receivableId")
                            ReceivableFormScreen(
                                viewModel = remember(receivableId) { receivableFormViewModelFactory(receivableId) },
                                onSaved = { navController.popBackStack() }
                            )
                        }
                    }
                }
            }
        }
    }
}
