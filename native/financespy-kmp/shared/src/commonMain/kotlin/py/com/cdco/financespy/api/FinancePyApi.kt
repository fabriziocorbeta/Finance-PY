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
import py.com.cdco.financespy.api.dto.BudgetDto
import py.com.cdco.financespy.api.dto.BudgetEnvelope
import py.com.cdco.financespy.api.dto.BudgetsEnvelope
import py.com.cdco.financespy.api.dto.CategoriesResponse
import py.com.cdco.financespy.api.dto.CategoryDto
import py.com.cdco.financespy.api.dto.CreateGoalBody
import py.com.cdco.financespy.api.dto.CreateGoalRequest
import py.com.cdco.financespy.api.dto.CreateRuleBody
import py.com.cdco.financespy.api.dto.CreateRuleRequest
import py.com.cdco.financespy.api.dto.GoalDto
import py.com.cdco.financespy.api.dto.GoalEnvelope
import py.com.cdco.financespy.api.dto.GoalsEnvelope
import py.com.cdco.financespy.api.dto.MerchantDto
import py.com.cdco.financespy.api.dto.RuleDto
import py.com.cdco.financespy.api.dto.RuleEnvelope
import py.com.cdco.financespy.api.dto.RuleRunDto
import py.com.cdco.financespy.api.dto.RuleRunsEnvelope
import py.com.cdco.financespy.api.dto.RulesEnvelope
import py.com.cdco.financespy.api.dto.TagDto
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.api.dto.TransactionsResponse
import py.com.cdco.financespy.api.dto.UpdateGoalBody
import py.com.cdco.financespy.api.dto.UpdateGoalRequest
import py.com.cdco.financespy.api.dto.UpdateRuleBody
import py.com.cdco.financespy.api.dto.UpdateRuleRequest

open class FinancePyApi(private val http: HttpClient) {
    suspend fun fetchAllAccounts(): List<AccountDto> {
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

    suspend fun fetchRecentTransactions(startDate: String): List<TransactionListItemDto> {
        val all = mutableListOf<TransactionListItemDto>()
        var page = 1
        while (true) {
            val response: TransactionsResponse = http.get("/api/v1/transactions") {
                parameter("page", page)
                parameter("per_page", 100)
                parameter("start_date", startDate)
            }.body()
            all += response.transactions
            if (page >= response.pagination.total_pages) break
            page++
        }
        return all
    }

    suspend fun fetchBalanceSheet(): BalanceSheetResponse = http.get("/api/v1/balance_sheet").body()

    suspend fun fetchAllRules(): List<RuleDto> {
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

    suspend fun fetchRuleRuns(ruleId: String): List<RuleRunDto> {
        val response: RuleRunsEnvelope = http.get("/api/v1/rule_runs") {
            parameter("rule_id", ruleId)
            parameter("per_page", 100)
        }.body()
        return response.data
    }

    suspend fun fetchCategories(): List<CategoryDto> {
        val response: CategoriesResponse = http.get("/api/v1/categories") {
            parameter("per_page", 100)
        }.body()
        return response.categories
    }

    suspend fun fetchMerchants(): List<MerchantDto> = http.get("/api/v1/merchants").body()

    suspend fun fetchTags(): List<TagDto> = http.get("/api/v1/tags").body()

    suspend fun createRule(body: CreateRuleBody): RuleDto {
        val response: RuleEnvelope = http.post("/api/v1/rules") {
            contentType(ContentType.Application.Json)
            setBody(CreateRuleRequest(rule = body))
        }.body()
        return response.data
    }

    suspend fun updateRule(id: String, body: UpdateRuleBody): RuleDto {
        val response: RuleEnvelope = http.patch("/api/v1/rules/$id") {
            contentType(ContentType.Application.Json)
            setBody(UpdateRuleRequest(rule = body))
        }.body()
        return response.data
    }

    suspend fun deleteRule(id: String) {
        http.delete("/api/v1/rules/$id")
    }

    suspend fun fetchAllGoals(): List<GoalDto> {
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

    suspend fun fetchGoal(id: String): GoalDto {
        val response: GoalEnvelope = http.get("/api/v1/goals/$id").body()
        return response.data
    }

    suspend fun createGoal(body: CreateGoalBody): GoalDto {
        val response: GoalEnvelope = http.post("/api/v1/goals") {
            contentType(ContentType.Application.Json)
            setBody(CreateGoalRequest(goal = body))
        }.body()
        return response.data
    }

    suspend fun updateGoal(id: String, body: UpdateGoalBody): GoalDto {
        val response: GoalEnvelope = http.patch("/api/v1/goals/$id") {
            contentType(ContentType.Application.Json)
            setBody(UpdateGoalRequest(goal = body))
        }.body()
        return response.data
    }

    suspend fun deleteGoal(id: String) {
        http.delete("/api/v1/goals/$id")
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

    suspend fun fetchBudget(id: String): BudgetDto {
        val response: BudgetEnvelope = http.get("/api/v1/budgets/$id").body()
        return response.data
    }
}
