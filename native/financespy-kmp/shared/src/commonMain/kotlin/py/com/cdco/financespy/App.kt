package py.com.cdco.financespy

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.navigation.NavItem
import py.com.cdco.financespy.navigation.NavItems
import py.com.cdco.financespy.navigation.NavPreferences
import py.com.cdco.financespy.navigation.Routes
import py.com.cdco.financespy.screens.NavCustomizationScreen
import py.com.cdco.financespy.screens.NavCustomizationViewModel
import py.com.cdco.financespy.theme.components.AppBottomNav
import py.com.cdco.financespy.theme.components.AppHamburgerMenu
import py.com.cdco.financespy.screens.AccountDetailScreen
import py.com.cdco.financespy.screens.AccountDetailViewModel
import py.com.cdco.financespy.screens.BudgetAllocationEditorScreen
import py.com.cdco.financespy.screens.BudgetAllocationEditorViewModel
import py.com.cdco.financespy.screens.BudgetDashboardScreen
import py.com.cdco.financespy.screens.BudgetDashboardViewModel
import py.com.cdco.financespy.screens.DashboardScreen
import py.com.cdco.financespy.screens.DashboardViewModel
import py.com.cdco.financespy.screens.FleetListScreen
import py.com.cdco.financespy.screens.FleetListViewModel
import py.com.cdco.financespy.screens.FleetVehicleDetailScreen
import py.com.cdco.financespy.screens.FleetVehicleDetailViewModel
import py.com.cdco.financespy.screens.GoalDetailScreen
import py.com.cdco.financespy.screens.GoalDetailViewModel
import py.com.cdco.financespy.screens.GoalFormScreen
import py.com.cdco.financespy.screens.GoalFormViewModel
import py.com.cdco.financespy.screens.GoalsListScreen
import py.com.cdco.financespy.screens.GoalsListViewModel
import py.com.cdco.financespy.screens.LoginScreen
import py.com.cdco.financespy.screens.OnboardingScreen
import py.com.cdco.financespy.screens.OnboardingViewModel
import py.com.cdco.financespy.screens.ReceivableDetailScreen
import py.com.cdco.financespy.screens.ReceivableDetailViewModel
import py.com.cdco.financespy.screens.ReceivableFormScreen
import py.com.cdco.financespy.screens.ReceivableFormViewModel
import py.com.cdco.financespy.screens.ReceivablesListScreen
import py.com.cdco.financespy.screens.ReceivablesListViewModel
import py.com.cdco.financespy.screens.ProductFormScreen
import py.com.cdco.financespy.screens.ProductFormViewModel
import py.com.cdco.financespy.screens.ProductsListScreen
import py.com.cdco.financespy.screens.ProductsListViewModel
import py.com.cdco.financespy.screens.PurchaseOrderDetailScreen
import py.com.cdco.financespy.screens.PurchaseOrderDetailViewModel
import py.com.cdco.financespy.screens.PurchaseOrderFormScreen
import py.com.cdco.financespy.screens.PurchaseOrderFormViewModel
import py.com.cdco.financespy.screens.PurchaseOrdersListScreen
import py.com.cdco.financespy.screens.PurchaseOrdersListViewModel
import py.com.cdco.financespy.screens.ReportsScreen
import py.com.cdco.financespy.screens.ReportsViewModel
import py.com.cdco.financespy.screens.RuleDetailScreen
import py.com.cdco.financespy.screens.SaleDetailScreen
import py.com.cdco.financespy.screens.SaleDetailViewModel
import py.com.cdco.financespy.screens.SaleFormScreen
import py.com.cdco.financespy.screens.SaleFormViewModel
import py.com.cdco.financespy.screens.SalesListScreen
import py.com.cdco.financespy.screens.SalesListViewModel
import py.com.cdco.financespy.screens.RuleDetailViewModel
import py.com.cdco.financespy.screens.RuleFormScreen
import py.com.cdco.financespy.screens.RuleFormViewModel
import py.com.cdco.financespy.screens.RulesListScreen
import py.com.cdco.financespy.screens.RulesListViewModel
import py.com.cdco.financespy.screens.SettingsScreen
import py.com.cdco.financespy.screens.SettingsViewModel
import py.com.cdco.financespy.screens.TransactionFormScreen
import py.com.cdco.financespy.screens.TransactionFormViewModel
import py.com.cdco.financespy.screens.TransactionsScreen
import py.com.cdco.financespy.screens.TransactionsViewModel
import py.com.cdco.financespy.theme.FinancePyColors
import py.com.cdco.financespy.theme.FinancePyTheme

@Composable
fun App(
    isLoggedIn: Boolean?,
    api: FinancePyApi,
    navPreferences: NavPreferences,
    needsOnboarding: Boolean = false,
    onLoginClick: () -> Unit,
    onLoggedOut: () -> Unit,
    onboardingViewModelFactory: () -> OnboardingViewModel,
    dashboardViewModelFactory: () -> DashboardViewModel,
    budgetDashboardViewModelFactory: () -> BudgetDashboardViewModel,
    budgetAllocationEditorViewModelFactory: (String) -> BudgetAllocationEditorViewModel,
    transactionsViewModelFactory: () -> TransactionsViewModel,
    transactionFormViewModelFactory: (String?) -> TransactionFormViewModel,
    rulesListViewModelFactory: () -> RulesListViewModel,
    ruleDetailViewModelFactory: (String) -> RuleDetailViewModel,
    ruleFormViewModelFactory: (String?) -> RuleFormViewModel,
    goalsListViewModelFactory: () -> GoalsListViewModel,
    goalDetailViewModelFactory: (String) -> GoalDetailViewModel,
    goalFormViewModelFactory: (String?) -> GoalFormViewModel,
    receivablesListViewModelFactory: () -> ReceivablesListViewModel,
    receivableDetailViewModelFactory: (String) -> ReceivableDetailViewModel,
    receivableFormViewModelFactory: (String?) -> ReceivableFormViewModel,
    productsListViewModelFactory: () -> ProductsListViewModel,
    productFormViewModelFactory: (String?) -> ProductFormViewModel,
    salesListViewModelFactory: () -> SalesListViewModel,
    saleDetailViewModelFactory: (String) -> SaleDetailViewModel,
    saleFormViewModelFactory: (String?) -> SaleFormViewModel,
    purchaseOrdersListViewModelFactory: () -> PurchaseOrdersListViewModel,
    purchaseOrderDetailViewModelFactory: (String) -> PurchaseOrderDetailViewModel,
    purchaseOrderFormViewModelFactory: (String?) -> PurchaseOrderFormViewModel,
    fleetListViewModelFactory: () -> FleetListViewModel,
    fleetVehicleDetailViewModelFactory: (String) -> FleetVehicleDetailViewModel,
    accountDetailViewModelFactory: (String) -> AccountDetailViewModel,
    settingsViewModelFactory: () -> SettingsViewModel,
    reportsViewModelFactory: () -> ReportsViewModel,
    onOpenNotificationSettings: (() -> Unit)? = null,
    onShareFile: ((ByteArray, String, String) -> Unit)? = null
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

                val settingsVm = remember { settingsViewModelFactory() }
                val settingsState by settingsVm.uiState.collectAsState()
                val isBusinessModeEnabled = settingsState.businessModeEnabled

                val navCustomizationVm = remember(isBusinessModeEnabled) {
                    NavCustomizationViewModel(navPreferences, isBusinessModeEnabled)
                }
                val navCustomizationState by navCustomizationVm.uiState.collectAsState()
                val pool = NavItems.pool(isBusinessModeEnabled)
                val barItems = navCustomizationState.selectedIds.mapNotNull { id -> pool.find { it.id == id } }
                val overflowItems = pool.filter { it.id !in navCustomizationState.selectedIds }

                var showHamburgerMenu by remember { mutableStateOf(false) }

                val businessRoutes = listOf(Routes.PRODUCTS, Routes.SALES, Routes.PURCHASE_ORDERS, Routes.FLEET)
                val isTopLevelRoute = currentRoute == Routes.DASHBOARD ||
                    currentRoute == Routes.BUDGETS ||
                    currentRoute == Routes.TRANSACTIONS ||
                    currentRoute == Routes.RULES ||
                    currentRoute == Routes.GOALS ||
                    currentRoute == Routes.RECEIVABLES ||
                    currentRoute == Routes.REPORTS ||
                    (isBusinessModeEnabled && currentRoute in businessRoutes)

                fun navigateToItem(item: NavItem) {
                    navController.navigate(item.route) { launchSingleTop = true }
                    showHamburgerMenu = false
                }

                Box(modifier = Modifier.fillMaxSize()) {
                    Scaffold(
                        modifier = Modifier
                            .fillMaxSize()
                            .background(FinancePyColors.surface())
                            .statusBarsPadding()
                            .navigationBarsPadding(),
                        containerColor = FinancePyColors.surface(),
                        bottomBar = {
                            if (isTopLevelRoute) {
                                AppBottomNav(
                                    items = barItems,
                                    currentRoute = currentRoute,
                                    onNavigate = { item -> navigateToItem(item) },
                                    onMoreClick = if (overflowItems.isNotEmpty()) {
                                        { showHamburgerMenu = true }
                                    } else null
                                )
                            }
                        }
                    ) { innerPadding ->
                    val startDestination = if (needsOnboarding) Routes.ONBOARDING else Routes.DASHBOARD

                    NavHost(
                        navController = navController,
                        startDestination = startDestination,
                        modifier = Modifier.padding(innerPadding)
                    ) {
                        composable(Routes.ONBOARDING) {
                            OnboardingScreen(
                                viewModel = remember { onboardingViewModelFactory() },
                                onComplete = {
                                    navController.navigate(Routes.DASHBOARD) {
                                        popUpTo(Routes.ONBOARDING) { inclusive = true }
                                    }
                                }
                            )
                        }
                        composable(Routes.DASHBOARD) {
                            DashboardScreen(
                                viewModel = remember { dashboardViewModelFactory() },
                                onAccountClick = { accountId -> navController.navigate(Routes.accountDetail(accountId)) },
                                onSettingsClick = { navController.navigate(Routes.SETTINGS) }
                            )
                        }
                        composable(Routes.SETTINGS) {
                            SettingsScreen(
                                viewModel = settingsVm,
                                onBack = { navController.popBackStack() },
                                onLoggedOut = onLoggedOut,
                                onOpenNotificationSettings = onOpenNotificationSettings,
                                onShareFile = onShareFile,
                                onNavigateToRules = { navController.navigate(Routes.RULES) },
                                onNavigateToNavCustomization = { navController.navigate(Routes.NAV_CUSTOMIZATION) }
                            )
                        }
                        composable(Routes.NAV_CUSTOMIZATION) {
                            NavCustomizationScreen(
                                viewModel = navCustomizationVm,
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable(Routes.BUDGETS) {
                            val budgetDashboardVm = remember { budgetDashboardViewModelFactory() }
                            BudgetDashboardScreen(
                                viewModel = budgetDashboardVm,
                                onNavigateToEditor = { budgetId ->
                                    navController.navigate(Routes.budgetAllocationEditor(budgetId))
                                },
                                onNavigateToCategoryTransactions = { _, _, _ ->
                                    navController.navigate(Routes.TRANSACTIONS)
                                }
                            )
                        }
                        composable(Routes.BUDGET_ALLOCATION_EDITOR) { entry ->
                            val budgetId = entry.arguments?.getString("budgetId") ?: return@composable
                            val editorVm = remember(budgetId) { budgetAllocationEditorViewModelFactory(budgetId) }
                            BudgetAllocationEditorScreen(
                                viewModel = editorVm,
                                onSaved = {
                                    budgetDashboardViewModelFactory().refresh()
                                    navController.popBackStack()
                                },
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable(Routes.TRANSACTIONS) {
                            TransactionsScreen(
                                viewModel = remember { transactionsViewModelFactory() },
                                onTransactionClick = { transactionId -> navController.navigate(Routes.transactionFormEdit(transactionId)) },
                                onCreateClick = { navController.navigate(Routes.transactionFormCreate()) }
                            )
                        }
                        composable(Routes.TRANSACTION_FORM) { entry ->
                            val transactionId = entry.arguments?.getString("transactionId")
                            TransactionFormScreen(
                                viewModel = remember(transactionId) { transactionFormViewModelFactory(transactionId) },
                                onSaved = {
                                    transactionsViewModelFactory().refresh()
                                    navController.popBackStack()
                                },
                                onCancel = { navController.popBackStack() }
                            )
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
                                onSaved = { navController.popBackStack() },
                                onCancel = { navController.popBackStack() }
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
                        composable(Routes.RECEIVABLES) {
                            ReceivablesListScreen(
                                viewModel = remember { receivablesListViewModelFactory() },
                                onReceivableClick = { receivableId -> navController.navigate(Routes.receivableDetail(receivableId)) },
                                onCreateClick = { navController.navigate(Routes.receivableFormCreate()) }
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
                        composable(Routes.PRODUCTS) {
                            ProductsListScreen(
                                viewModel = remember { productsListViewModelFactory() },
                                onProductClick = { productId -> navController.navigate(Routes.productFormEdit(productId)) },
                                onCreateClick = { navController.navigate(Routes.productFormCreate()) }
                            )
                        }
                        composable(Routes.PRODUCT_FORM) { entry ->
                            val productId = entry.arguments?.getString("productId")
                            ProductFormScreen(
                                viewModel = remember(productId) { productFormViewModelFactory(productId) },
                                onSaved = { navController.popBackStack() },
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable(Routes.SALES) {
                            SalesListScreen(
                                viewModel = remember { salesListViewModelFactory() },
                                onSaleClick = { saleId -> navController.navigate(Routes.saleDetail(saleId)) },
                                onCreateClick = { navController.navigate(Routes.saleFormCreate()) }
                            )
                        }
                        composable(Routes.SALE_DETAIL) { entry ->
                            val saleId = entry.arguments?.getString("saleId") ?: return@composable
                            SaleDetailScreen(
                                viewModel = remember(saleId) { saleDetailViewModelFactory(saleId) },
                                onEditClick = { navController.navigate(Routes.saleFormEdit(saleId)) },
                                onDeleted = { navController.popBackStack(Routes.SALES, inclusive = false) },
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable(Routes.SALE_FORM) { entry ->
                            val saleId = entry.arguments?.getString("saleId")
                            SaleFormScreen(
                                viewModel = remember(saleId) { saleFormViewModelFactory(saleId) },
                                onSaved = { navController.popBackStack() },
                                onCancel = { navController.popBackStack() }
                            )
                        }
                        composable(Routes.PURCHASE_ORDERS) {
                            PurchaseOrdersListScreen(
                                viewModel = remember { purchaseOrdersListViewModelFactory() },
                                onPurchaseOrderClick = { poId -> navController.navigate(Routes.purchaseOrderDetail(poId)) },
                                onCreateClick = { navController.navigate(Routes.purchaseOrderFormCreate()) }
                            )
                        }
                        composable(Routes.PURCHASE_ORDER_DETAIL) { entry ->
                            val poId = entry.arguments?.getString("purchaseOrderId") ?: return@composable
                            PurchaseOrderDetailScreen(
                                viewModel = remember(poId) { purchaseOrderDetailViewModelFactory(poId) },
                                onEditClick = { navController.navigate(Routes.purchaseOrderFormEdit(poId)) },
                                onDeleted = { navController.popBackStack(Routes.PURCHASE_ORDERS, inclusive = false) },
                                onBack = { navController.popBackStack() }
                            )
                        }
                        composable(Routes.PURCHASE_ORDER_FORM) { entry ->
                            val poId = entry.arguments?.getString("purchaseOrderId")
                            PurchaseOrderFormScreen(
                                viewModel = remember(poId) { purchaseOrderFormViewModelFactory(poId) },
                                onSaved = { navController.popBackStack() },
                                onCancel = { navController.popBackStack() }
                            )
                        }
                        composable(Routes.REPORTS) {
                            ReportsScreen(
                                viewModel = remember { reportsViewModelFactory() },
                                onShareFile = onShareFile
                            )
                        }
                        composable(Routes.FLEET) {
                            FleetListScreen(
                                viewModel = remember { fleetListViewModelFactory() },
                                onVehicleClick = { vehicleId -> navController.navigate(Routes.fleetVehicleDetail(vehicleId)) }
                            )
                        }
                        composable(Routes.FLEET_VEHICLE_DETAIL) { entry ->
                            val vehicleId = entry.arguments?.getString("vehicleId") ?: return@composable
                            FleetVehicleDetailScreen(
                                viewModel = remember(vehicleId) { fleetVehicleDetailViewModelFactory(vehicleId) },
                                onBack = { navController.popBackStack() }
                            )
                        }
                    }
                    }

                    if (showHamburgerMenu) {
                        AppHamburgerMenu(
                            items = overflowItems,
                            onItemClick = { item -> navigateToItem(item) },
                            onDismiss = { showHamburgerMenu = false }
                        )
                    }
                }
            }
        }
    }
}
