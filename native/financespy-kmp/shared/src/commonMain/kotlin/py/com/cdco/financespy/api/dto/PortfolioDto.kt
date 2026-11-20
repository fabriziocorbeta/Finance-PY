package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

// Named "Portfolio*" (not "Holding*") to avoid colliding with the
// dashboard's own HoldingDto (api/dto/DashboardDto.kt), which is a
// different, pre-formatted top-5 shape from a separate endpoint.
@Serializable
data class PortfolioHoldingsResponse(
    val holdings: List<PortfolioHoldingDto>,
    val pagination: PaginationDto
)

@Serializable
data class PortfolioHoldingDto(
    val id: String,
    val date: String,
    val qty: String,
    val price: String,
    val price_cents: Long? = null,
    val amount: String,
    val amount_cents: Long? = null,
    val currency: String,
    val cost_basis_source: String? = null,
    val account: PortfolioHoldingAccountDto,
    val security: PortfolioHoldingSecurityDto,
    val avg_cost: String? = null,
    val avg_cost_cents: Long? = null
)

@Serializable
data class PortfolioHoldingAccountDto(
    val id: String,
    val name: String,
    val account_type: String
)

@Serializable
data class PortfolioHoldingSecurityDto(
    val id: String,
    val ticker: String,
    val name: String? = null
)

@Serializable
data class SecurityPricesResponse(
    val security_prices: List<SecurityPriceDto>,
    val pagination: PaginationDto
)

@Serializable
data class SecurityPriceDto(
    val id: String,
    val date: String,
    val price: String,
    val price_amount: String,
    val currency: String,
    val provisional: Boolean = false,
    val security: SecurityPriceSecurityDto? = null
)

@Serializable
data class SecurityPriceSecurityDto(
    val id: String,
    val ticker: String,
    val name: String? = null,
    val exchange_operating_mic: String? = null
)
