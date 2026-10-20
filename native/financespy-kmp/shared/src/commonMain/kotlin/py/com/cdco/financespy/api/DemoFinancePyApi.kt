package py.com.cdco.financespy.api

import io.ktor.client.HttpClient
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.AccountGroupDto
import py.com.cdco.financespy.api.dto.AccountItemDto
import py.com.cdco.financespy.api.dto.AccountRefDto
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
}
