package py.com.cdco.financespy.api

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.request.get
import io.ktor.client.request.parameter
import py.com.cdco.financespy.api.dto.AccountDto
import py.com.cdco.financespy.api.dto.AccountsResponse
import py.com.cdco.financespy.api.dto.BalanceSheetResponse
import py.com.cdco.financespy.api.dto.TransactionListItemDto
import py.com.cdco.financespy.api.dto.TransactionsResponse

class FinancePyApi(private val http: HttpClient) {
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
}
