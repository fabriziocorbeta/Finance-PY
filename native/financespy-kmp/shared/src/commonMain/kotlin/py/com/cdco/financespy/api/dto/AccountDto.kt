package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class AccountsResponse(val accounts: List<AccountDto>, val pagination: PaginationDto)

@Serializable
data class AccountDto(
    val id: String,
    val name: String,
    val balance_cents: Long,
    val cash_balance_cents: Long,
    val currency: String,
    val classification: String,
    val account_type: String,
    val subtype: String? = null,
    val status: String,
    val updated_at: String
)

@Serializable
data class PaginationDto(val page: Int, val per_page: Int, val total_count: Int, val total_pages: Int)

// Unión de los campos extra de los 7 tipos de cuenta "simples" que soporta
// POST /api/v1/accounts (ver PERMITTED_ACCOUNTABLE_ATTRS del lado del
// backend) -- el server solo usa los que aplican al accountable_type
// elegido e ignora el resto, así que no hace falta una clase por tipo.
@Serializable
data class CreateAccountAccountableAttributes(
    val subtype: String? = null,
    val tax_treatment: String? = null,
    val make: String? = null,
    val model: String? = null,
    val year: Int? = null,
    val mileage_value: Double? = null,
    val mileage_unit: String? = null,
    val available_credit: Double? = null,
    val minimum_payment: Double? = null,
    val apr: Double? = null,
    val annual_fee: Double? = null,
    val expiration_date: String? = null,
    val rate_type: String? = null,
    val interest_rate: Double? = null,
    val term_months: Int? = null,
    val initial_balance: Double? = null
)

@Serializable
data class CreateAccountBody(
    val accountable_type: String,
    val name: String,
    val balance: Double,
    val currency: String,
    val institution_name: String? = null,
    val notes: String? = null,
    val accountable_attributes: CreateAccountAccountableAttributes? = null
)

@Serializable
data class CreateAccountRequest(
    val account: CreateAccountBody
)
