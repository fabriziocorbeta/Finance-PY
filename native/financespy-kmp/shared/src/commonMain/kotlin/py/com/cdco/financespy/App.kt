package py.com.cdco.financespy

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.TabRowDefaults
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import py.com.cdco.financespy.navigation.Routes
import py.com.cdco.financespy.screens.AccountDetailScreen
import py.com.cdco.financespy.screens.AccountDetailViewModel
import py.com.cdco.financespy.screens.DashboardScreen
import py.com.cdco.financespy.screens.DashboardViewModel
import py.com.cdco.financespy.screens.LoginScreen
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
    transactionsViewModelFactory: () -> TransactionsViewModel,
    rulesListViewModelFactory: () -> RulesListViewModel,
    ruleDetailViewModelFactory: (String) -> RuleDetailViewModel,
    ruleFormViewModelFactory: (String?) -> RuleFormViewModel,
    accountDetailViewModelFactory: (String) -> AccountDetailViewModel
) {
    FinancePyTheme {
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
                    if (currentRoute == Routes.DASHBOARD || currentRoute == Routes.TRANSACTIONS || currentRoute == Routes.RULES) {
                        val selectedIndex = when (currentRoute) {
                            Routes.TRANSACTIONS -> 1
                            Routes.RULES -> 2
                            else -> 0
                        }
                        TabRow(
                            selectedTabIndex = selectedIndex,
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
                        }
                    }

                    NavHost(navController = navController, startDestination = Routes.DASHBOARD) {
                        composable(Routes.DASHBOARD) {
                            DashboardScreen(
                                viewModel = remember { dashboardViewModelFactory() },
                                onAccountClick = { accountId -> navController.navigate(Routes.accountDetail(accountId)) }
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
                    }
                }
            }
        }
    }
}
