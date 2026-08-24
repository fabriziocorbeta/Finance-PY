package py.com.cdco.financespy.screens

import io.ktor.client.plugins.ClientRequestException
import io.ktor.client.statement.bodyAsText
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.CreateBudgetBody
import py.com.cdco.financespy.api.dto.UpdateBudgetBody
import py.com.cdco.financespy.db.BudgetDao
import py.com.cdco.financespy.sync.currentIsoDate

@Serializable
private data class ApiErrorResponseBody(
    val error: String? = null,
    val message: String? = null,
    val errors: List<String>? = null
)

data class BudgetFormState(
    val isEditing: Boolean = false,
    val year: String = "",
    val month: String = "",
    val budgetedSpending: String = "",
    val expectedIncome: String = "",
    val isSaving: Boolean = false,
    val error: String? = null
)

class BudgetFormViewModel(
    private val scope: CoroutineScope,
    private val budgetId: String?,
    private val api: FinancePyApi,
    private val budgetDao: BudgetDao
) {
    private val _state = MutableStateFlow(
        BudgetFormState(
            isEditing = budgetId != null,
            year = currentIsoDate().take(4),
            month = currentIsoDate().substring(5, 7)
        )
    )
    val state: StateFlow<BudgetFormState> = _state

    init {
        if (budgetId != null) {
            scope.launch {
                budgetDao.findById(budgetId)?.let { budget ->
                    val yearVal = if (budget.startDate.length >= 4) budget.startDate.take(4) else ""
                    val monthVal = if (budget.startDate.length >= 7) budget.startDate.substring(5, 7) else ""
                    _state.value = _state.value.copy(
                        year = yearVal,
                        month = monthVal,
                        budgetedSpending = if (budget.budgetedSpending > 0) budget.budgetedSpending.toString() else "",
                        expectedIncome = if (budget.expectedIncome > 0) budget.expectedIncome.toString() else ""
                    )
                }
            }
        }
    }

    fun updateYear(value: String) { _state.value = _state.value.copy(year = value) }
    fun updateMonth(value: String) { _state.value = _state.value.copy(month = value) }
    fun updateBudgetedSpending(value: String) { _state.value = _state.value.copy(budgetedSpending = value) }
    fun updateExpectedIncome(value: String) { _state.value = _state.value.copy(expectedIncome = value) }

    fun save(onSaved: () -> Unit) {
        val s = _state.value
        val budgeted = s.budgetedSpending.toDoubleOrNull()
        if (budgeted == null || budgeted < 0) {
            _state.value = s.copy(error = "Ingresá un monto válido para el presupuesto de gastos")
            return
        }

        val expected = s.expectedIncome.toDoubleOrNull()

        scope.launch {
            _state.value = s.copy(isSaving = true, error = null)

            val result = if (budgetId != null) {
                runCatching {
                    api.updateBudget(
                        id = budgetId,
                        body = UpdateBudgetBody(
                            budgeted_spending = budgeted,
                            expected_income = expected
                        )
                    )
                }
            } else {
                val yearNum = s.year.toIntOrNull()
                val monthNum = s.month.toIntOrNull()
                if (yearNum == null || monthNum == null || monthNum !in 1..12) {
                    _state.value = _state.value.copy(isSaving = false, error = "Ingresá un año y mes válidos")
                    return@launch
                }
                val monthStr = monthNum.toString().padStart(2, '0')
                val startDateStr = "$yearNum-$monthStr-01"

                runCatching {
                    api.createBudget(
                        body = CreateBudgetBody(
                            start_date = startDateStr,
                            budgeted_spending = budgeted,
                            expected_income = expected
                        )
                    )
                }
            }

            result
                .onSuccess { onSaved() }
                .onFailure { e ->
                    val errorMsg = extractErrorMessage(e)
                    _state.value = _state.value.copy(isSaving = false, error = errorMsg)
                }
        }
    }

    private suspend fun extractErrorMessage(e: Throwable): String {
        if (e is ClientRequestException) {
            runCatching {
                val text = e.response.bodyAsText()
                val json = Json { ignoreUnknownKeys = true }
                val parsed = json.decodeFromString<ApiErrorResponseBody>(text)
                if (!parsed.errors.isNullOrEmpty()) {
                    return parsed.errors.joinToString(", ")
                }
                if (!parsed.message.isNullOrEmpty()) {
                    return parsed.message
                }
            }
        }
        return e.message ?: "Error al guardar"
    }
}
