package py.com.cdco.financespy.api

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.delete
import io.ktor.client.request.get
import io.ktor.client.request.parameter
import io.ktor.client.request.patch
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.AccountsResponse
import py.com.cdco.financespy.api.dto.BalanceSheetResponse
import py.com.cdco.financespy.api.dto.BudgetCategoryDto
import py.com.cdco.financespy.api.dto.BudgetCategoryEnvelope
import py.com.cdco.financespy.api.dto.BudgetDto
import py.com.cdco.financespy.api.dto.BudgetEnvelope
import py.com.cdco.financespy.api.dto.BudgetsEnvelope
import py.com.cdco.financespy.api.dto.CategoriesResponse
import py.com.cdco.financespy.api.dto.CategoryDto
import py.com.cdco.financespy.api.dto.CreateGoalBody
import py.com.cdco.financespy.api.dto.DashboardDto
import py.com.cdco.financespy.api.dto.CreateGoalRequest
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
import py.com.cdco.financespy.api.dto.ReceivableDto
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

open class FinancePyApi(private val http: HttpClient) {
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
}
