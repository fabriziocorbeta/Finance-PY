package py.com.cdco.financespy.api

import io.ktor.client.HttpClient
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.AccountGroupDto
import py.com.cdco.financespy.api.dto.AccountItemDto
import py.com.cdco.financespy.api.dto.AccountRefDto
import py.com.cdco.financespy.api.dto.BudgetCategoryDto
import py.com.cdco.financespy.api.dto.BudgetDto
import py.com.cdco.financespy.api.dto.CashflowSankeyDto
import py.com.cdco.financespy.api.dto.CategoryRefDto
import py.com.cdco.financespy.api.dto.ClassificationGroupDto
import py.com.cdco.financespy.api.dto.DashboardBalanceSheetDto
import py.com.cdco.financespy.api.dto.DashboardDto
import py.com.cdco.financespy.api.dto.DonutCategoryDto
import py.com.cdco.financespy.api.dto.FamilySettingsDto
import py.com.cdco.financespy.api.dto.GoalDto
import py.com.cdco.financespy.api.dto.InvestmentSummaryDto
import py.com.cdco.financespy.api.dto.MerchantRefDto
import py.com.cdco.financespy.api.dto.NetWorthDto
import py.com.cdco.financespy.api.dto.NetWorthSeriesPointDto
import py.com.cdco.financespy.api.dto.OutflowsDonutDto
import py.com.cdco.financespy.api.dto.PaginationDto
import py.com.cdco.financespy.api.dto.PeriodDto
import py.com.cdco.financespy.api.dto.ReceivableDto
import py.com.cdco.financespy.api.dto.RuleDto
import py.com.cdco.financespy.api.dto.SankeyLinkDto
import py.com.cdco.financespy.api.dto.SankeyNodeDto
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.api.dto.TransactionsResponse
import py.com.cdco.financespy.api.dto.TrendDto
import py.com.cdco.financespy.api.dto.UserDto

class DemoFinancePyApi : FinancePyApi(HttpClient()) {
    override suspend fun fetchAllAccounts(): List<AccountDto> = listOf(
        AccountDto(
            id = "acc-ita",
            name = "Itaú Cuenta Corriente",
            balance_cents = 48_500_000_00L,
            cash_balance_cents = 48_500_000_00L,
            currency = "PYG",
            classification = "asset",
            account_type = "Depository",
            subtype = "checking",
            status = "active",
            updated_at = "2026-10-18"
        ),
        AccountDto(
            id = "acc-cont",
            name = "Continental Ahorro",
            balance_cents = 92_300_000_00L,
            cash_balance_cents = 92_300_000_00L,
            currency = "PYG",
            classification = "asset",
            account_type = "Depository",
            subtype = "savings",
            status = "active",
            updated_at = "2026-10-18"
        ),
        AccountDto(
            id = "acc-tc",
            name = "Visa Infinite Itaú",
            balance_cents = 8_450_000_00L,
            cash_balance_cents = 8_450_000_00L,
            currency = "PYG",
            classification = "liability",
            account_type = "CreditCard",
            subtype = "credit_card",
            status = "active",
            updated_at = "2026-10-18"
        )
    )

    override suspend fun fetchRecentTransactions(startDate: String): List<TransactionListItemDto> =
        sampleTransactions()

    override suspend fun fetchTransactionsPage(
        page: Int,
        perPage: Int,
        startDate: String?,
        endDate: String?,
        categoryId: String?,
        search: String?,
        accountId: String?,
        type: String?
    ): TransactionsResponse {
        val all = sampleTransactions().filter { tx ->
            val matchAccount = accountId == null || tx.account?.id == accountId
            val matchType = type == null || type == "all" || tx.classification == type
            val matchSearch = search.isNullOrBlank() || tx.name.contains(search, ignoreCase = true)
            matchAccount && matchType && matchSearch
        }
        return TransactionsResponse(
            transactions = all,
            pagination = PaginationDto(page = page, per_page = perPage, total_count = all.size, total_pages = 1)
        )
    }

    override suspend fun fetchAllRules(): List<RuleDto> = emptyList()
    override suspend fun fetchAllGoals(): List<GoalDto> = emptyList()
    override suspend fun fetchAllReceivables(): List<ReceivableDto> = emptyList()

    override suspend fun fetchDashboard(period: String?): DashboardDto = DashboardDto(
        greeting_name = "Fabrizio",
        currency = "PYG",
        period = PeriodDto(key = period ?: "current_month", label = "Este mes"),
        net_worth = NetWorthDto(
            amount = 184_350_000.0,
            amount_cents = 184_350_000_00L,
            currency = "PYG",
            series = listOf(
                NetWorthSeriesPointDto("2026-10-01", "1 Oct", 171_000_000.0),
                NetWorthSeriesPointDto("2026-10-07", "7 Oct", 175_400_000.0),
                NetWorthSeriesPointDto("2026-10-12", "12 Oct", 179_800_000.0),
                NetWorthSeriesPointDto("2026-10-18", "18 Oct", 184_350_000.0)
            ),
            trend = TrendDto(
                value = 13_350_000.0,
                percent = 7.8,
                percent_formatted = "+7,8%",
                direction = "up",
                color = "#10B981"
            )
        ),
        balance_sheet = DashboardBalanceSheetDto(
            classification_groups = listOf(
                ClassificationGroupDto(
                    classification = "asset",
                    name = "Activos",
                    total = 192_800_000.0,
                    account_groups = listOf(
                        AccountGroupDto(
                            key = "depository",
                            name = "Efectivo y Bancos",
                            color = "#10B981",
                            weight = 73.0,
                            total = 140_800_000.0,
                            accounts = listOf(
                                AccountItemDto("acc-cont", "Continental Ahorro", 92_300_000.0, currency = "PYG"),
                                AccountItemDto("acc-ita", "Itaú Cuenta Corriente", 48_500_000.0, currency = "PYG")
                            )
                        ),
                        AccountGroupDto(
                            key = "investment",
                            name = "Inversiones CDA / Fondos",
                            color = "#3B82F6",
                            weight = 27.0,
                            total = 52_000_000.0,
                            accounts = listOf(
                                AccountItemDto("acc-basa", "Basa Capital Fondo Mutuo", 52_000_000.0, currency = "PYG")
                            )
                        )
                    )
                ),
                ClassificationGroupDto(
                    classification = "liability",
                    name = "Pasivos",
                    total = 8_450_000.0,
                    account_groups = listOf(
                        AccountGroupDto(
                            key = "credit_card",
                            name = "Tarjetas de Crédito",
                            color = "#EF4444",
                            weight = 100.0,
                            total = 8_450_000.0,
                            accounts = listOf(
                                AccountItemDto("acc-tc", "Visa Infinite Itaú", 8_450_000.0, currency = "PYG")
                            )
                        )
                    )
                )
            )
        ),
        cashflow_sankey = CashflowSankeyDto(
            currency_symbol = "Gs.",
            nodes = listOf(
                SankeyNodeDto("Ingresos", 24_500_000.0, 100.0, "#10B981"),
                SankeyNodeDto("Supermercado", 4_200_000.0, 17.1, "#F59E0B"),
                SankeyNodeDto("Ahorro", 20_300_000.0, 82.9, "#3B82F6")
            ),
            links = listOf(
                SankeyLinkDto(0, 1, 4_200_000.0, "#F59E0B", 17.1),
                SankeyLinkDto(0, 2, 20_300_000.0, "#3B82F6", 82.9)
            )
        ),
        outflows_donut = OutflowsDonutDto(
            currency = "PYG",
            currency_symbol = "Gs.",
            total = 6_850_000.0,
            categories = listOf(
                DonutCategoryDto("cat-1", "Supermercado", 3_150_000.0, "PYG", 46.0, "#10B981"),
                DonutCategoryDto("cat-2", "Restaurantes", 1_850_000.0, "PYG", 27.0, "#F59E0B"),
                DonutCategoryDto("cat-3", "Combustible", 1_200_000.0, "PYG", 17.5, "#3B82F6"),
                DonutCategoryDto("cat-4", "Servicios", 650_000.0, "PYG", 9.5, "#8B5CF6")
            )
        ),
        investment_summary = InvestmentSummaryDto(portfolio_value = 52_000_000.0, currency = "PYG")
    )

    override suspend fun fetchFamilySettings(): FamilySettingsDto = FamilySettingsDto(
        id = "fam-1",
        currency = "PYG",
        locale = "es",
        date_format = "dd/MM/yyyy",
        month_start_day = 1,
        created_at = "2026-01-01",
        updated_at = "2026-10-18",
        name = "Familia Corbeta",
        business_mode_enabled = true,
        current_user = UserDto(
            id = "usr-1",
            email = "fabrizio@financespy.com",
            first_name = "Fabrizio",
            last_name = "Corbeta",
            role = "admin"
        ),
        users = emptyList()
    )

    private fun sampleTransactions(): List<TransactionListItemDto> = listOf(
        TransactionListItemDto(
            id = "tx-1",
            date = "2026-10-18",
            amount_cents = 485_000L,
            signed_amount_cents = -485_000L,
            currency = "PYG",
            name = "Superseis Mcal. López",
            classification = "expense",
            account = AccountRefDto("acc-tc", "Visa Infinite Itaú", "CreditCard"),
            category = CategoryRefDto("cat-1", "Supermercado", "#10B981", "shopping-cart"),
            merchant = MerchantRefDto("mer-1", "Superseis"),
            created_at = "2026-10-18T14:20:00Z",
            updated_at = "2026-10-18T14:20:00Z"
        ),
        TransactionListItemDto(
            id = "tx-2",
            date = "2026-10-18",
            amount_cents = 165_000L,
            signed_amount_cents = -165_000L,
            currency = "PYG",
            name = "Café Consulado",
            classification = "expense",
            account = AccountRefDto("acc-ita", "Itaú Cuenta Corriente", "Depository"),
            category = CategoryRefDto("cat-2", "Restaurantes", "#F59E0B", "utensils"),
            merchant = MerchantRefDto("mer-2", "Café Consulado"),
            created_at = "2026-10-18T10:15:00Z",
            updated_at = "2026-10-18T10:15:00Z",
            pending = true
        ),
        TransactionListItemDto(
            id = "tx-3",
            date = "2026-10-17",
            amount_cents = 15_500_000L,
            signed_amount_cents = 15_500_000L,
            currency = "PYG",
            name = "Cobro Consultoría Mensual",
            classification = "income",
            account = AccountRefDto("acc-cont", "Continental Ahorro", "Depository"),
            category = CategoryRefDto("cat-3", "Ingresos", "#10B981", "briefcase"),
            merchant = null,
            created_at = "2026-10-17T18:00:00Z",
            updated_at = "2026-10-17T18:00:00Z"
        ),
        TransactionListItemDto(
            id = "tx-4",
            date = "2026-10-17",
            amount_cents = 350_000L,
            signed_amount_cents = -350_000L,
            currency = "PYG",
            name = "Shell Aviadores del Chaco",
            classification = "expense",
            account = AccountRefDto("acc-tc", "Visa Infinite Itaú", "CreditCard"),
            category = CategoryRefDto("cat-4", "Combustible", "#3B82F6", "fuel"),
            merchant = MerchantRefDto("mer-4", "Shell"),
            created_at = "2026-10-17T09:30:00Z",
            updated_at = "2026-10-17T09:30:00Z"
        ),
        TransactionListItemDto(
            id = "tx-5",
            date = "2026-10-16",
            amount_cents = 290_000L,
            signed_amount_cents = -290_000L,
            currency = "PYG",
            name = "ANDE Factura Octubre",
            classification = "expense",
            account = AccountRefDto("acc-ita", "Itaú Cuenta Corriente", "Depository"),
            category = CategoryRefDto("cat-5", "Servicios", "#8B5CF6", "bolt"),
            merchant = MerchantRefDto("mer-5", "ANDE"),
            created_at = "2026-10-16T11:00:00Z",
            updated_at = "2026-10-16T11:00:00Z"
        )
    )

    override suspend fun fetchAllBudgets(): List<BudgetDto> = listOf(demoBudgetOct2026)

    override suspend fun fetchBudget(idOrParam: String): BudgetDto = demoBudgetOct2026

    private val demoBudgetOct2026 = BudgetDto(
        id = "b-2026-10",
        name = "octubre 2026",
        param = "2026-10",
        start_date = "2026-10-01",
        end_date = "2026-10-31",
        currency = "USD",
        initialized = true,
        current = true,
        previous_budget_param = "2026-09",
        next_budget_param = "2026-11",
        allocations_valid = true,
        budgeted_spending = 4_117_700.0,
        actual_spending = 54_480_442.08,
        available_to_spend = -50_362_742.08,
        expected_income = 58_598_142.08,
        actual_income = 58_598_142.08,
        allocated_spending = 4_117_700.0,
        available_to_allocate = 4_113_375.0,
        allocated_percent = 100.0,
        percent_of_budget_spent = 1323.0,
        categories = listOf(
            BudgetCategoryDto(
                id = "bc-1",
                budget_id = "b-2026-10",
                category_id = "cat-1",
                category_name = "Shopping",
                category_color = "#10B981",
                budgeted_spending = 675.0,
                actual_spending = 983998.4349,
                available_to_spend = -983323.4349,
                over_budget = true,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-2",
                budget_id = "b-2026-10",
                category_id = "cat-2",
                category_name = "Entertainment",
                category_color = "#8B5CF6",
                budgeted_spending = 450.0,
                actual_spending = 633202.8111,
                available_to_spend = -632752.8111,
                over_budget = true,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-3",
                budget_id = "b-2026-10",
                category_id = "cat-3",
                category_name = "Travel",
                category_color = "#06B6D4",
                budgeted_spending = 500.0,
                actual_spending = 116687.7988,
                available_to_spend = -116187.7988,
                over_budget = true,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-4",
                budget_id = "b-2026-10",
                category_id = "cat-4",
                category_name = "Food & Dining",
                category_color = "#F59E0B",
                budgeted_spending = 1200.0,
                actual_spending = 697693.4771,
                available_to_spend = -696493.4771,
                over_budget = true,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-5",
                budget_id = "b-2026-10",
                category_id = "cat-5",
                category_name = "Groceries",
                category_color = "#D97706",
                budgeted_spending = 800.0,
                actual_spending = 1595061.3033,
                available_to_spend = -1594261.3033,
                over_budget = true,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-6",
                budget_id = "b-2026-10",
                category_id = "cat-6",
                category_name = "Housing",
                category_color = "#3B82F6",
                budgeted_spending = 2200.0,
                actual_spending = 2200.0,
                available_to_spend = 0.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-7",
                budget_id = "b-2026-10",
                category_id = "cat-7",
                category_name = "Utilities",
                category_color = "#EAB308",
                budgeted_spending = 400.0,
                actual_spending = 350.0,
                available_to_spend = 50.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-8",
                budget_id = "b-2026-10",
                category_id = "cat-8",
                category_name = "Health & Fitness",
                category_color = "#059669",
                budgeted_spending = 200.0,
                actual_spending = 180.0,
                available_to_spend = 20.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-9",
                budget_id = "b-2026-10",
                category_id = "cat-9",
                category_name = "Personal Care",
                category_color = "#EC4899",
                budgeted_spending = 150.0,
                actual_spending = 120.0,
                available_to_spend = 30.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-10",
                budget_id = "b-2026-10",
                category_id = "cat-10",
                category_name = "Education",
                category_color = "#6366F1",
                budgeted_spending = 300.0,
                actual_spending = 300.0,
                available_to_spend = 0.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-11",
                budget_id = "b-2026-10",
                category_id = "cat-11",
                category_name = "Transportation",
                category_color = "#F43F5E",
                budgeted_spending = 300.0,
                actual_spending = 250.0,
                available_to_spend = 50.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-12",
                budget_id = "b-2026-10",
                category_id = "cat-12",
                category_name = "Subscriptions",
                category_color = "#7C3AED",
                budgeted_spending = 100.0,
                actual_spending = 85.0,
                available_to_spend = 15.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-13",
                budget_id = "b-2026-10",
                category_id = "cat-13",
                category_name = "Insurance",
                category_color = "#0284C7",
                budgeted_spending = 450.0,
                actual_spending = 450.0,
                available_to_spend = 0.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-14",
                budget_id = "b-2026-10",
                category_id = "cat-14",
                category_name = "Gifts & Donations",
                category_color = "#EF4444",
                budgeted_spending = 100.0,
                actual_spending = 50.0,
                available_to_spend = 50.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-15",
                budget_id = "b-2026-10",
                category_id = "cat-15",
                category_name = "Pets",
                category_color = "#84CC16",
                budgeted_spending = 100.0,
                actual_spending = 95.0,
                available_to_spend = 5.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-16",
                budget_id = "b-2026-10",
                category_id = "cat-16",
                category_name = "Kids",
                category_color = "#14B8A6",
                budgeted_spending = 250.0,
                actual_spending = 200.0,
                available_to_spend = 50.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-17",
                budget_id = "b-2026-10",
                category_id = "cat-17",
                category_name = "Home Improvement",
                category_color = "#64748B",
                budgeted_spending = 300.0,
                actual_spending = 150.0,
                available_to_spend = 150.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-18",
                budget_id = "b-2026-10",
                category_id = "cat-18",
                category_name = "Electronics",
                category_color = "#71717A",
                budgeted_spending = 400.0,
                actual_spending = 400.0,
                available_to_spend = 0.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-19",
                budget_id = "b-2026-10",
                category_id = "cat-19",
                category_name = "Clothing",
                category_color = "#78716C",
                budgeted_spending = 200.0,
                actual_spending = 180.0,
                available_to_spend = 20.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-20",
                budget_id = "b-2026-10",
                category_id = "cat-20",
                category_name = "Office Supplies",
                category_color = "#2563EB",
                budgeted_spending = 50.0,
                actual_spending = 45.0,
                available_to_spend = 5.0,
                over_budget = false,
                budgeted = true
            ),
            BudgetCategoryDto(
                id = "bc-21",
                budget_id = "b-2026-10",
                category_id = "cat-21",
                category_name = "Miscellaneous",
                category_color = "#9CA3AF",
                budgeted_spending = 100.0,
                actual_spending = 50.0,
                available_to_spend = 50.0,
                over_budget = false,
                budgeted = true
            )
        )
    )
}
