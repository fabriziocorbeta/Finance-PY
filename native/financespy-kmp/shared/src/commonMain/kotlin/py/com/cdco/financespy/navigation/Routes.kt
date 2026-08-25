package py.com.cdco.financespy.navigation

object Routes {
    const val DASHBOARD = "dashboard"
    const val TRANSACTIONS = "transactions"
    const val RULES = "rules"
    const val GOALS = "goals"
    const val ACCOUNT_DETAIL = "account/{accountId}"
    const val RULE_DETAIL = "rule/{ruleId}"
    const val RULE_FORM = "rule_form?ruleId={ruleId}"
    const val GOAL_DETAIL = "goal/{goalId}"
    const val GOAL_FORM = "goal_form?goalId={goalId}"

    fun accountDetail(accountId: String) = "account/$accountId"
    fun ruleDetail(ruleId: String) = "rule/$ruleId"
    fun ruleFormEdit(ruleId: String) = "rule_form?ruleId=$ruleId"
    fun ruleFormCreate() = "rule_form"
    fun goalDetail(goalId: String) = "goal/$goalId"
    fun goalFormEdit(goalId: String) = "goal_form?goalId=$goalId"
    fun goalFormCreate() = "goal_form"
}
