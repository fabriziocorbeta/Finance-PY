package py.com.cdco.financespy.navigation

object Routes {
    const val DASHBOARD = "dashboard"
    const val TRANSACTIONS = "transactions"
    const val RULES = "rules"
    const val RECEIVABLES = "receivables"
    const val ACCOUNT_DETAIL = "account/{accountId}"
    const val RULE_DETAIL = "rule/{ruleId}"
    const val RULE_FORM = "rule_form?ruleId={ruleId}"
    const val RECEIVABLE_DETAIL = "receivable/{receivableId}"
    const val RECEIVABLE_FORM = "receivable_form?receivableId={receivableId}"

    fun accountDetail(accountId: String) = "account/$accountId"
    fun ruleDetail(ruleId: String) = "rule/$ruleId"
    fun ruleFormEdit(ruleId: String) = "rule_form?ruleId=$ruleId"
    fun ruleFormCreate() = "rule_form"
    fun receivableDetail(receivableId: String) = "receivable/$receivableId"
    fun receivableFormEdit(receivableId: String) = "receivable_form?receivableId=$receivableId"
    fun receivableFormCreate() = "receivable_form"
}
