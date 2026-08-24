package py.com.cdco.financespy.navigation

object Routes {
    const val DASHBOARD = "dashboard"
    const val TRANSACTIONS = "transactions"
    const val RULES = "rules"
    const val BUDGETS = "budgets"
    const val ACCOUNT_DETAIL = "account/{accountId}"
    const val RULE_DETAIL = "rule/{ruleId}"
    const val RULE_FORM = "rule_form?ruleId={ruleId}"
    const val BUDGET_DETAIL = "budget/{budgetId}"
    const val BUDGET_FORM = "budget_form?budgetId={budgetId}"

    fun accountDetail(accountId: String) = "account/$accountId"
    fun ruleDetail(ruleId: String) = "rule/$ruleId"
    fun ruleFormEdit(ruleId: String) = "rule_form?ruleId=$ruleId"
    fun ruleFormCreate() = "rule_form"
    fun budgetDetail(budgetId: String) = "budget/$budgetId"
    fun budgetFormEdit(budgetId: String) = "budget_form?budgetId=$budgetId"
    fun budgetFormCreate() = "budget_form"
}
