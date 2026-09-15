package py.com.cdco.financespy.api

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.delete
import io.ktor.client.request.forms.formData
import io.ktor.client.request.forms.submitFormWithBinaryData
import io.ktor.client.request.get
import io.ktor.client.request.parameter
import io.ktor.client.request.patch
import io.ktor.client.request.post
import io.ktor.client.request.put
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsBytes
import io.ktor.http.ContentType
import io.ktor.http.Headers
import io.ktor.http.HttpHeaders
import io.ktor.http.contentType
import py.com.cdco.financespy.api.dto.FamilyExportDto
import py.com.cdco.financespy.api.dto.FamilyExportEnvelope
import py.com.cdco.financespy.api.dto.FamilyExportsEnvelope
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.NavPreferencesDto
import py.com.cdco.financespy.api.dto.UpayImportResponseDto
import py.com.cdco.financespy.api.dto.UpayImportResultDto
import py.com.cdco.financespy.api.dto.BalanceSeriesDto
import py.com.cdco.financespy.api.dto.AccountsResponse
import py.com.cdco.financespy.api.dto.BalanceSheetResponse
import py.com.cdco.financespy.api.dto.BudgetCategoryDto
import py.com.cdco.financespy.api.dto.BudgetCategoryEnvelope
import py.com.cdco.financespy.api.dto.BudgetDto
import py.com.cdco.financespy.api.dto.FamilySettingsDto
import py.com.cdco.financespy.api.dto.BudgetEnvelope
import py.com.cdco.financespy.api.dto.BudgetsEnvelope
import py.com.cdco.financespy.api.dto.CategoriesResponse
import py.com.cdco.financespy.api.dto.CategoryDto
import py.com.cdco.financespy.api.dto.CreateGoalBody
import py.com.cdco.financespy.api.dto.CreateGoalPledgeBody
import py.com.cdco.financespy.api.dto.CreateFleetVehicleBody
import py.com.cdco.financespy.api.dto.CreateFleetVehicleRequest
import py.com.cdco.financespy.api.dto.CreateFuelLogBody
import py.com.cdco.financespy.api.dto.CreateFuelLogRequest
import py.com.cdco.financespy.api.dto.CreateGoalPledgeRequest
import py.com.cdco.financespy.api.dto.DashboardDto
import py.com.cdco.financespy.api.dto.FleetVehicleDto
import py.com.cdco.financespy.api.dto.FleetVehicleEnvelope
import py.com.cdco.financespy.api.dto.FleetVehiclesEnvelope
import py.com.cdco.financespy.api.dto.FuelLogDto
import py.com.cdco.financespy.api.dto.FuelLogEnvelope
import py.com.cdco.financespy.api.dto.CreateGoalRequest
import py.com.cdco.financespy.api.dto.GoalPledgeDto
import py.com.cdco.financespy.api.dto.GoalPledgeEnvelope
import py.com.cdco.financespy.api.dto.GoalPledgesEnvelope
import py.com.cdco.financespy.api.dto.CreateReceivableBody
import py.com.cdco.financespy.api.dto.CreateReceivableRequest
import py.com.cdco.financespy.api.dto.CreateRuleBody
import py.com.cdco.financespy.api.dto.CreateRuleRequest
import py.com.cdco.financespy.api.dto.CreateTransactionBody
import py.com.cdco.financespy.api.dto.CreateTransactionRequest
import py.com.cdco.financespy.api.dto.GoalDto
import py.com.cdco.financespy.api.dto.GoalEnvelope
import py.com.cdco.financespy.api.dto.GoalsEnvelope
import py.com.cdco.financespy.api.dto.MerchantDto
import py.com.cdco.financespy.api.dto.ProductDto
import py.com.cdco.financespy.api.dto.ProductResponseDto
import py.com.cdco.financespy.api.dto.ProductsResponseDto
import py.com.cdco.financespy.api.dto.PurchaseOrderDto
import py.com.cdco.financespy.api.dto.PurchaseOrderResponseDto
import py.com.cdco.financespy.api.dto.PurchaseOrdersResponseDto
import py.com.cdco.financespy.api.dto.SaleDto
import py.com.cdco.financespy.api.dto.SaleResponseDto
import py.com.cdco.financespy.api.dto.SalesResponseDto
import py.com.cdco.financespy.api.dto.ReceivableDto
import py.com.cdco.financespy.api.dto.ReportsSummaryDto
import py.com.cdco.financespy.api.dto.ReceivableEnvelope
import py.com.cdco.financespy.api.dto.ReceivablesEnvelope
import py.com.cdco.financespy.api.dto.RuleDto
import py.com.cdco.financespy.api.dto.RuleEnvelope
import py.com.cdco.financespy.api.dto.RuleRegistryDto
import py.com.cdco.financespy.api.dto.RuleRunDto
import py.com.cdco.financespy.api.dto.RuleRunsEnvelope
import py.com.cdco.financespy.api.dto.RulesEnvelope
import py.com.cdco.financespy.api.dto.TagDto
import py.com.cdco.financespy.api.dto.CreateTransferBody
import py.com.cdco.financespy.api.dto.CreateTransferRequest
import py.com.cdco.financespy.api.dto.TransferDto
import py.com.cdco.financespy.api.dto.TransactionDetailDto
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.api.dto.TransactionsResponse
import py.com.cdco.financespy.api.dto.UpdateBudgetCategoryBody
import py.com.cdco.financespy.api.dto.UpdateBudgetCategoryRequest
import py.com.cdco.financespy.api.dto.UpdateGoalBody
import py.com.cdco.financespy.api.dto.UpdateGoalRequest
import py.com.cdco.financespy.api.dto.UpdateReceivableBody
import py.com.cdco.financespy.api.dto.UpdateReceivableRequest
import py.com.cdco.financespy.api.dto.UpdateRuleBody
import py.com.cdco.financespy.api.dto.UpdateRuleRequest
import py.com.cdco.financespy.api.dto.UpdateTransactionBody
import py.com.cdco.financespy.api.dto.UpdateTransactionRequest
import py.com.cdco.financespy.api.dto.UpdateUserBody
import py.com.cdco.financespy.api.dto.UpdateUserRequest

open class FinancePyApi(private val http: HttpClient) {
    open suspend fun updateUser(body: UpdateUserBody): FamilySettingsDto {
        return http.patch("/api/v1/users/me") {
            contentType(ContentType.Application.Json)
            setBody(UpdateUserRequest(user = body))
        }.body()
    }
    open suspend fun fetchNavItemOrder(): List<String>? {
        return http.get("/api/v1/users/me/nav_preferences").body<NavPreferencesDto>().nav_item_order
    }

    open suspend fun updateNavItemOrder(itemIds: List<String>): List<String>? {
        return http.put("/api/v1/users/me/nav_preferences") {
            contentType(ContentType.Application.Json)
            setBody(NavPreferencesDto(nav_item_order = itemIds))
        }.body<NavPreferencesDto>().nav_item_order
    }

    open suspend fun fetchAccountBalanceSeries(accountId: String, period: String = "last_30_days"): BalanceSeriesDto {
        return http.get("/api/v1/accounts/$accountId/balance_series") {
            parameter("period", period)
        }.body()
    }

    open suspend fun fetchAllAccounts(): List<AccountDto> {
        val all = mutableListOf<AccountDto>()
        var page = 1
        while (true) {
            val response: AccountsResponse = http.get("/api/v1/accounts") {
                parameter("page", page)
                parameter("per_page", 100)
            }.body()
            all += response.accounts
            if (page >= response.pagination.total_pages) break
            page++
        }
        return all
    }

    open suspend fun fetchRecentTransactions(startDate: String): List<TransactionListItemDto> {
        return fetchTransactions(startDate = startDate)
    }

    open suspend fun fetchTransactions(
        startDate: String? = null,
        endDate: String? = null,
        categoryId: String? = null,
        search: String? = null,
        accountId: String? = null,
        type: String? = null
    ): List<TransactionListItemDto> {
        val all = mutableListOf<TransactionListItemDto>()
        var page = 1
        while (true) {
            val response: TransactionsResponse = http.get("/api/v1/transactions") {
                parameter("page", page)
                parameter("per_page", 100)
                if (startDate != null) parameter("start_date", startDate)
                if (endDate != null) parameter("end_date", endDate)
                if (categoryId != null) parameter("category_id", categoryId)
                if (search != null) parameter("search", search)
                if (accountId != null) parameter("account_id", accountId)
                if (type != null) parameter("type", type)
            }.body()
            all += response.transactions
            if (page >= response.pagination.total_pages) break
            page++
        }
        return all
    }

    /**
     * Single-page fetch of /api/v1/transactions (does NOT auto-paginate through every page
     * like fetchTransactions does) - lets callers page through results N-at-a-time.
     */
    open suspend fun fetchTransactionsPage(
        page: Int,
        perPage: Int = 25,
        startDate: String? = null,
        endDate: String? = null,
        categoryId: String? = null,
        search: String? = null,
        accountId: String? = null,
        type: String? = null
    ): TransactionsResponse {
        return http.get("/api/v1/transactions") {
            parameter("page", page)
            parameter("per_page", perPage)
            if (startDate != null) parameter("start_date", startDate)
            if (endDate != null) parameter("end_date", endDate)
            if (categoryId != null) parameter("category_id", categoryId)
            if (search != null) parameter("search", search)
            if (accountId != null) parameter("account_id", accountId)
            if (type != null) parameter("type", type)
        }.body()
    }

    open suspend fun fetchTransaction(id: String): TransactionDetailDto =
        http.get("/api/v1/transactions/$id").body()

    open suspend fun createTransaction(body: CreateTransactionBody): TransactionDetailDto {
        return http.post("/api/v1/transactions") {
            contentType(ContentType.Application.Json)
            setBody(CreateTransactionRequest(transaction = body))
        }.body()
    }

    open suspend fun updateTransaction(id: String, body: UpdateTransactionBody): TransactionDetailDto {
        return http.patch("/api/v1/transactions/$id") {
            contentType(ContentType.Application.Json)
            setBody(UpdateTransactionRequest(transaction = body))
        }.body()
    }

    open suspend fun deleteTransaction(id: String) {
        http.delete("/api/v1/transactions/$id")
    }

    open suspend fun fetchBalanceSheet(): BalanceSheetResponse = http.get("/api/v1/balance_sheet").body()

    open suspend fun fetchDashboard(period: String? = null): DashboardDto {
        return http.get("/api/v1/dashboard") {
            if (period != null) {
                parameter("period", period)
            }
        }.body()
    }

    open suspend fun fetchAllRules(): List<RuleDto> {
        val all = mutableListOf<RuleDto>()
        var page = 1
        while (true) {
            val response: RulesEnvelope = http.get("/api/v1/rules") {
                parameter("page", page)
                parameter("per_page", 100)
            }.body()
            all += response.data
            if (response.meta.next_page == null) break
            page = response.meta.next_page!!
        }
        return all
    }

    open suspend fun fetchRuleRuns(ruleId: String): List<RuleRunDto> {
        val response: RuleRunsEnvelope = http.get("/api/v1/rule_runs") {
            parameter("rule_id", ruleId)
            parameter("per_page", 100)
        }.body()
        return response.data
    }

    open suspend fun fetchCategories(): List<CategoryDto> {
        val response: CategoriesResponse = http.get("/api/v1/categories") {
            parameter("per_page", 100)
        }.body()
        return response.categories
    }

    open suspend fun fetchMerchants(): List<MerchantDto> = http.get("/api/v1/merchants").body()

    open suspend fun fetchTags(): List<TagDto> = http.get("/api/v1/tags").body()

    open suspend fun createRule(body: CreateRuleBody): RuleDto {
        val response: RuleEnvelope = http.post("/api/v1/rules") {
            contentType(ContentType.Application.Json)
            setBody(CreateRuleRequest(rule = body))
        }.body()
        return response.data
    }

    open suspend fun updateRule(id: String, body: UpdateRuleBody): RuleDto {
        val response: RuleEnvelope = http.patch("/api/v1/rules/$id") {
            contentType(ContentType.Application.Json)
            setBody(UpdateRuleRequest(rule = body))
        }.body()
        return response.data
    }

    open suspend fun deleteRule(id: String) {
        http.delete("/api/v1/rules/$id")
    }

    open suspend fun fetchRuleRegistry(resourceType: String = "transaction"): RuleRegistryDto {
        return http.get("/api/v1/rules/registry") {
            parameter("resource_type", resourceType)
        }.body()
    }

    open suspend fun fetchRule(id: String): RuleDto {
        val response: RuleEnvelope = http.get("/api/v1/rules/$id").body()
        return response.data
    }

    open suspend fun fetchAllGoals(): List<GoalDto> {
        val all = mutableListOf<GoalDto>()
        var page = 1
        while (true) {
            val response: GoalsEnvelope = http.get("/api/v1/goals") {
                parameter("page", page)
                parameter("per_page", 100)
            }.body()
            all += response.data
            if (response.meta.next_page == null) break
            page = response.meta.next_page!!
        }
        return all
    }

    open suspend fun fetchGoal(id: String): GoalDto {
        val response: GoalEnvelope = http.get("/api/v1/goals/$id").body()
        return response.data
    }

    open suspend fun createGoal(body: CreateGoalBody): GoalDto {
        val response: GoalEnvelope = http.post("/api/v1/goals") {
            contentType(ContentType.Application.Json)
            setBody(CreateGoalRequest(goal = body))
        }.body()
        return response.data
    }

    open suspend fun updateGoal(id: String, body: UpdateGoalBody): GoalDto {
        val response: GoalEnvelope = http.patch("/api/v1/goals/$id") {
            contentType(ContentType.Application.Json)
            setBody(UpdateGoalRequest(goal = body))
        }.body()
        return response.data
    }

    open suspend fun deleteGoal(id: String) {
        http.delete("/api/v1/goals/$id")
    }

    open suspend fun fetchGoalPledges(goalId: String): List<GoalPledgeDto> {
        val response: GoalPledgesEnvelope = http.get("/api/v1/goals/$goalId/pledges").body()
        return response.data
    }

    open suspend fun createGoalPledge(goalId: String, body: CreateGoalPledgeBody): GoalPledgeDto {
        val response: GoalPledgeEnvelope = http.post("/api/v1/goals/$goalId/pledges") {
            contentType(ContentType.Application.Json)
            setBody(CreateGoalPledgeRequest(pledge = body))
        }.body()
        return response.data
    }

    open suspend fun cancelGoalPledge(goalId: String, pledgeId: String) {
        http.delete("/api/v1/goals/$goalId/pledges/$pledgeId")
    }

    open suspend fun renewGoalPledge(goalId: String, pledgeId: String): GoalPledgeDto {
        val response: GoalPledgeEnvelope = http.patch("/api/v1/goals/$goalId/pledges/$pledgeId/renew").body()
        return response.data
    }

    open suspend fun fetchAllReceivables(): List<ReceivableDto> {
        val all = mutableListOf<ReceivableDto>()
        var page = 1
        while (true) {
            val response: ReceivablesEnvelope = http.get("/api/v1/receivables") {
                parameter("page", page)
                parameter("per_page", 100)
            }.body()
            all += response.data
            val nextPage = response.meta?.next_page ?: break
            page = nextPage
        }
        return all
    }

    open suspend fun fetchReceivable(id: String): ReceivableDto {
        val response: ReceivableEnvelope = http.get("/api/v1/receivables/$id").body()
        return response.data
    }

    open suspend fun createReceivable(body: CreateReceivableBody): ReceivableDto {
        val response: ReceivableEnvelope = http.post("/api/v1/receivables") {
            contentType(ContentType.Application.Json)
            setBody(CreateReceivableRequest(receivable = body))
        }.body()
        return response.data
    }

    open suspend fun updateReceivable(id: String, body: UpdateReceivableBody): ReceivableDto {
        val response: ReceivableEnvelope = http.patch("/api/v1/receivables/$id") {
            contentType(ContentType.Application.Json)
            setBody(UpdateReceivableRequest(receivable = body))
        }.body()
        return response.data
    }

    open suspend fun deleteReceivable(id: String) {
        http.delete("/api/v1/receivables/$id")
    }

    open suspend fun createTransfer(body: CreateTransferBody): TransferDto {
        return http.post("/api/v1/transfers") {
            contentType(ContentType.Application.Json)
            setBody(CreateTransferRequest(transfer = body))
        }.body()
    }

    open suspend fun fetchAllBudgets(): List<BudgetDto> {
        val all = mutableListOf<BudgetDto>()
        var page = 1
        while (true) {
            val response: BudgetsEnvelope = http.get("/api/v1/budgets") {
                parameter("page", page)
                parameter("per_page", 100)
            }.body()
            all += response.data
            val meta = response.meta
            if (meta == null || meta.next_page == null) break
            page = meta.next_page
        }
        return all
    }

    open suspend fun fetchBudget(idOrParam: String): BudgetDto {
        val response: BudgetEnvelope = http.get("/api/v1/budgets/$idOrParam").body()
        return response.data
    }

    open suspend fun updateBudgetCategory(
        budgetId: String,
        categoryId: String,
        budgetedSpending: Double?
    ): BudgetCategoryDto {
        val response: BudgetCategoryEnvelope = http.patch("/api/v1/budgets/$budgetId/budget_categories/$categoryId") {
            contentType(ContentType.Application.Json)
            setBody(UpdateBudgetCategoryRequest(budget_category = UpdateBudgetCategoryBody(budgeted_spending = budgetedSpending)))
        }.body()
        return response.data
    }

    open suspend fun fetchFamilySettings(): FamilySettingsDto = http.get("/api/v1/family_settings").body()

    open suspend fun uploadUpayImport(accountId: String, fileBytes: ByteArray, fileName: String): UpayImportResultDto {
        val response: UpayImportResponseDto = http.submitFormWithBinaryData(
            url = "/api/v1/imports",
            formData = formData {
                append("type", "UpayImport")
                append("account_id", accountId)
                append("publish", "true")
                append("file", fileBytes, Headers.build {
                    append(HttpHeaders.ContentType, "text/csv")
                    append(HttpHeaders.ContentDisposition, "form-data; name=\"file\"; filename=\"$fileName\"")
                })
            }
        ).body()
        return response.data
    }

    open suspend fun fetchImport(importId: String): UpayImportResultDto {
        val response: UpayImportResponseDto = http.get("/api/v1/imports/$importId").body()
        return response.data
    }

    // --- Products ---
    open suspend fun fetchAllProducts(): List<ProductDto> {
        val response: ProductsResponseDto = http.get("/api/v1/products") {
            parameter("per_page", 100)
        }.body()
        return response.data
    }

    open suspend fun fetchProduct(id: String): ProductDto {
        val response: ProductResponseDto = http.get("/api/v1/products/$id").body()
        return response.data
    }

    open suspend fun createProduct(product: ProductDto): ProductDto {
        val response: ProductResponseDto = http.post("/api/v1/products") {
            contentType(ContentType.Application.Json)
            setBody(mapOf("product" to product))
        }.body()
        return response.data
    }

    open suspend fun updateProduct(id: String, product: ProductDto): ProductDto {
        val response: ProductResponseDto = http.patch("/api/v1/products/$id") {
            contentType(ContentType.Application.Json)
            setBody(mapOf("product" to product))
        }.body()
        return response.data
    }

    open suspend fun deleteProduct(id: String) {
        http.delete("/api/v1/products/$id")
    }

    // --- Sales ---
    open suspend fun fetchAllSales(): List<SaleDto> {
        val response: SalesResponseDto = http.get("/api/v1/sales") {
            parameter("per_page", 100)
        }.body()
        return response.data
    }

    open suspend fun fetchSale(id: String): SaleDto {
        val response: SaleResponseDto = http.get("/api/v1/sales/$id").body()
        return response.data
    }

    open suspend fun createSale(salePayload: Map<String, Any?>): SaleDto {
        val response: SaleResponseDto = http.post("/api/v1/sales") {
            contentType(ContentType.Application.Json)
            setBody(mapOf("sale" to salePayload))
        }.body()
        return response.data
    }

    open suspend fun updateSale(id: String, salePayload: Map<String, Any?>): SaleDto {
        val response: SaleResponseDto = http.patch("/api/v1/sales/$id") {
            contentType(ContentType.Application.Json)
            setBody(mapOf("sale" to salePayload))
        }.body()
        return response.data
    }

    open suspend fun deleteSale(id: String) {
        http.delete("/api/v1/sales/$id")
    }

    open suspend fun completeSale(id: String): SaleDto {
        val response: SaleResponseDto = http.post("/api/v1/sales/$id/complete").body()
        return response.data
    }

    open suspend fun cancelSale(id: String): SaleDto {
        val response: SaleResponseDto = http.post("/api/v1/sales/$id/cancel").body()
        return response.data
    }

    // --- Purchase Orders ---
    open suspend fun fetchAllPurchaseOrders(): List<PurchaseOrderDto> {
        val response: PurchaseOrdersResponseDto = http.get("/api/v1/purchase_orders") {
            parameter("per_page", 100)
        }.body()
        return response.data
    }

    open suspend fun fetchPurchaseOrder(id: String): PurchaseOrderDto {
        val response: PurchaseOrderResponseDto = http.get("/api/v1/purchase_orders/$id").body()
        return response.data
    }

    open suspend fun createPurchaseOrder(poPayload: Map<String, Any?>): PurchaseOrderDto {
        val response: PurchaseOrderResponseDto = http.post("/api/v1/purchase_orders") {
            contentType(ContentType.Application.Json)
            setBody(mapOf("purchase_order" to poPayload))
        }.body()
        return response.data
    }

    open suspend fun updatePurchaseOrder(id: String, poPayload: Map<String, Any?>): PurchaseOrderDto {
        val response: PurchaseOrderResponseDto = http.patch("/api/v1/purchase_orders/$id") {
            contentType(ContentType.Application.Json)
            setBody(mapOf("purchase_order" to poPayload))
        }.body()
        return response.data
    }

    open suspend fun deletePurchaseOrder(id: String) {
        http.delete("/api/v1/purchase_orders/$id")
    }

    open suspend fun receivePurchaseOrder(id: String): PurchaseOrderDto {
        val response: PurchaseOrderResponseDto = http.post("/api/v1/purchase_orders/$id/receive").body()
        return response.data
    }

    open suspend fun cancelPurchaseOrder(id: String): PurchaseOrderDto {
        val response: PurchaseOrderResponseDto = http.post("/api/v1/purchase_orders/$id/cancel").body()
        return response.data
    }

    open suspend fun fetchReportsSummary(
        periodType: String = "monthly",
        startDate: String? = null,
        endDate: String? = null
    ): ReportsSummaryDto {
        return http.get("/api/v1/reports/summary") {
            parameter("period_type", periodType)
            if (startDate != null) parameter("start_date", startDate)
            if (endDate != null) parameter("end_date", endDate)
        }.body()
    }

    open suspend fun fetchFleetVehicles(): List<FleetVehicleDto> {
        val all = mutableListOf<FleetVehicleDto>()
        var page = 1
        while (true) {
            val response: FleetVehiclesEnvelope = http.get("/api/v1/fleet_vehicles") {
                parameter("page", page)
                parameter("per_page", 100)
            }.body()
            all += response.data
            val meta = response.meta
            if (meta == null || meta.next_page == null) break
            page = meta.next_page
        }
        return all
    }

    open suspend fun fetchFleetVehicle(id: String): FleetVehicleDto {
        val response: FleetVehicleEnvelope = http.get("/api/v1/fleet_vehicles/$id").body()
        return response.data
    }

    open suspend fun createFleetVehicle(body: CreateFleetVehicleBody): FleetVehicleDto {
        val response: FleetVehicleEnvelope = http.post("/api/v1/fleet_vehicles") {
            contentType(ContentType.Application.Json)
            setBody(CreateFleetVehicleRequest(fleet_vehicle = body))
        }.body()
        return response.data
    }

    open suspend fun deleteFleetVehicle(id: String) {
        http.delete("/api/v1/fleet_vehicles/$id")
    }

    open suspend fun createFuelLog(vehicleId: String, body: CreateFuelLogBody): FuelLogDto {
        val response: FuelLogEnvelope = http.post("/api/v1/fleet_vehicles/$vehicleId/fuel_logs") {
            contentType(ContentType.Application.Json)
            setBody(CreateFuelLogRequest(fuel_log = body))
        }.body()
        return response.data
    }

    open suspend fun deleteFuelLog(vehicleId: String, fuelLogId: String) {
        http.delete("/api/v1/fleet_vehicles/$vehicleId/fuel_logs/$fuelLogId")
    }

    // --- Family Data Exports ---
    open suspend fun fetchFamilyExports(page: Int = 1, perPage: Int = 25): FamilyExportsEnvelope {
        return http.get("/api/v1/family_exports") {
            parameter("page", page)
            parameter("per_page", perPage)
        }.body()
    }

    open suspend fun createFamilyExport(): FamilyExportDto {
        val response: FamilyExportEnvelope = http.post("/api/v1/family_exports").body()
        return response.data
    }

    open suspend fun downloadFamilyExport(id: String): ByteArray {
        return http.get("/api/v1/family_exports/$id/download").bodyAsBytes()
    }

    open suspend fun exportTransactionsCsv(
        periodType: String = "monthly",
        startDate: String? = null,
        endDate: String? = null
    ): ByteArray {
        return http.get("/api/v1/reports/export_transactions") {
            parameter("period_type", periodType)
            if (startDate != null) parameter("start_date", startDate)
            if (endDate != null) parameter("end_date", endDate)
        }.bodyAsBytes()
    }
}
