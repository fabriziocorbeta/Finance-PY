package py.com.cdco.financespy.screens

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import py.com.cdco.financespy.api.FinancePyApi
import py.com.cdco.financespy.api.dto.CreateAccountAccountableAttributes
import py.com.cdco.financespy.api.dto.CreateAccountBody
import py.com.cdco.financespy.db.AccountDao
import py.com.cdco.financespy.db.AccountEntity

// 7 de los 9 tipos de cuenta que soporta la web -- Property (alta multi-paso
// con dirección/tasación) y Receivable (flujo nativo propio aparte, ver
// pantallas de Cuentas a Cobrar) quedan afuera de este formulario genérico.
enum class AccountableTypeOption(val apiValue: String, val label: String) {
    DEPOSITORY("Depository", "Cuenta bancaria / Efectivo"),
    CREDIT_CARD("CreditCard", "Tarjeta de crédito"),
    INVESTMENT("Investment", "Inversión"),
    VEHICLE("Vehicle", "Vehículo"),
    LOAN("Loan", "Préstamo"),
    CRYPTO("Crypto", "Criptomoneda"),
    OTHER_ASSET("OtherAsset", "Otro activo")
}

data class AccountFormState(
    val accountableType: AccountableTypeOption = AccountableTypeOption.DEPOSITORY,
    val name: String = "",
    val balance: String = "",
    val currency: String = "PYG",
    val institutionName: String = "",
    val notes: String = "",
    // Campos extra por tipo -- solo se envían los que corresponden al tipo elegido.
    val availableCredit: String = "",
    val apr: String = "",
    val vehicleMake: String = "",
    val vehicleModel: String = "",
    val vehicleYear: String = "",
    val interestRate: String = "",
    val termMonths: String = "",
    val investmentSubtype: String = "",
    val isSaving: Boolean = false,
    val error: String? = null
)

class AccountFormViewModel(
    private val scope: CoroutineScope,
    private val api: FinancePyApi,
    private val accountDao: AccountDao
) {
    private val _state = MutableStateFlow(AccountFormState())
    val state: StateFlow<AccountFormState> = _state.asStateFlow()

    fun selectType(type: AccountableTypeOption) {
        _state.value = _state.value.copy(accountableType = type)
    }

    fun updateName(value: String) { _state.value = _state.value.copy(name = value) }
    fun updateBalance(value: String) { _state.value = _state.value.copy(balance = value) }
    fun updateCurrency(value: String) { _state.value = _state.value.copy(currency = value) }
    fun updateInstitutionName(value: String) { _state.value = _state.value.copy(institutionName = value) }
    fun updateNotes(value: String) { _state.value = _state.value.copy(notes = value) }
    fun updateAvailableCredit(value: String) { _state.value = _state.value.copy(availableCredit = value) }
    fun updateApr(value: String) { _state.value = _state.value.copy(apr = value) }
    fun updateVehicleMake(value: String) { _state.value = _state.value.copy(vehicleMake = value) }
    fun updateVehicleModel(value: String) { _state.value = _state.value.copy(vehicleModel = value) }
    fun updateVehicleYear(value: String) { _state.value = _state.value.copy(vehicleYear = value) }
    fun updateInterestRate(value: String) { _state.value = _state.value.copy(interestRate = value) }
    fun updateTermMonths(value: String) { _state.value = _state.value.copy(termMonths = value) }
    fun updateInvestmentSubtype(value: String) { _state.value = _state.value.copy(investmentSubtype = value) }

    fun save(onSaved: () -> Unit) {
        val s = _state.value
        if (s.name.isBlank()) {
            _state.value = s.copy(error = "Ingresá un nombre para la cuenta")
            return
        }
        val balanceValue = s.balance.toDoubleOrNull()
        if (balanceValue == null) {
            _state.value = s.copy(error = "Ingresá un saldo inicial válido")
            return
        }

        scope.launch {
            _state.value = s.copy(isSaving = true, error = null)
            try {
                val attrs = when (s.accountableType) {
                    AccountableTypeOption.CREDIT_CARD -> CreateAccountAccountableAttributes(
                        available_credit = s.availableCredit.toDoubleOrNull(),
                        apr = s.apr.toDoubleOrNull()
                    )
                    AccountableTypeOption.VEHICLE -> CreateAccountAccountableAttributes(
                        make = s.vehicleMake.ifBlank { null },
                        model = s.vehicleModel.ifBlank { null },
                        year = s.vehicleYear.toIntOrNull()
                    )
                    AccountableTypeOption.LOAN -> CreateAccountAccountableAttributes(
                        interest_rate = s.interestRate.toDoubleOrNull(),
                        term_months = s.termMonths.toIntOrNull()
                    )
                    AccountableTypeOption.INVESTMENT -> CreateAccountAccountableAttributes(
                        subtype = s.investmentSubtype.ifBlank { null }
                    )
                    else -> null
                }

                val body = CreateAccountBody(
                    accountable_type = s.accountableType.apiValue,
                    name = s.name,
                    balance = balanceValue,
                    currency = s.currency.uppercase().ifBlank { "PYG" },
                    institution_name = s.institutionName.ifBlank { null },
                    notes = s.notes.ifBlank { null },
                    accountable_attributes = attrs
                )

                val created = api.createAccount(body)
                accountDao.upsertAll(
                    listOf(
                        AccountEntity(
                            id = created.id,
                            name = created.name,
                            balanceCents = created.balance_cents,
                            cashBalanceCents = created.cash_balance_cents,
                            currency = created.currency,
                            classification = created.classification,
                            accountType = created.account_type,
                            subtype = created.subtype,
                            status = created.status,
                            updatedAt = created.updated_at
                        )
                    )
                )
                onSaved()
            } catch (e: Exception) {
                _state.value = _state.value.copy(isSaving = false, error = e.message ?: "Error al crear la cuenta")
                return@launch
            }
            _state.value = _state.value.copy(isSaving = false)
        }
    }
}
