package py.com.cdco.financespy.api.dto

import kotlinx.serialization.Serializable

@Serializable
data class MarketPointDto(
    val date: String,
    val value: Double,
    val open: Double? = null,
    val high: Double? = null,
    val low: Double? = null,
    val volume: Long? = null
)

@Serializable
data class MarketFundamentalsDto(
    val market_cap: Double? = null,
    val pe_ratio: Double? = null,
    val forward_pe: Double? = null,
    val eps: Double? = null,
    val dividend_yield: Double? = null,
    val beta: Double? = null,
    val avg_volume: Long? = null,
    val open_price: Double? = null,
    val bid: Double? = null,
    val ask: Double? = null,
    val target_mean_price: Double? = null,
    val recommendation_key: String? = null,
    val sector: String? = null,
    val industry: String? = null,
    val website: String? = null,
    val description: String? = null,
    val earnings_date: String? = null,
    val ex_dividend_date: String? = null,
    val market_state: String? = null,
    val pre_market_price: Double? = null,
    val pre_market_change_percent: Double? = null,
    val post_market_price: Double? = null,
    val post_market_change_percent: Double? = null
)

@Serializable
data class MarketNewsItemDto(
    val title: String,
    val publisher: String = "Yahoo Finance",
    val link: String,
    val published_at: String? = null
)

@Serializable
data class MarketQuoteDto(
    val ticker: String,
    val name: String,
    val category: String = "equity",
    val currency: String = "USD",
    val exchange_name: String? = null,
    val current_price: Double? = null,
    val previous_close: Double? = null,
    val change: Double? = null,
    val change_percent: Double? = null,
    val period_change: Double? = null,
    val period_change_percent: Double? = null,
    val day_high: Double? = null,
    val day_low: Double? = null,
    val fifty_two_week_high: Double? = null,
    val fifty_two_week_low: Double? = null,
    val volume: Long? = null,
    val watchlist_item_id: String? = null,
    val security_id: String? = null,
    val points: List<MarketPointDto> = emptyList(),
    val fundamentals: MarketFundamentalsDto? = null,
    val news: List<MarketNewsItemDto> = emptyList()
)

@Serializable
data class MarketTrackerResponseDto(
    val index_quotes: List<MarketQuoteDto> = emptyList(),
    val watchlist_quotes: List<MarketQuoteDto> = emptyList(),
    val holding_quotes: List<MarketQuoteDto> = emptyList(),
    val featured_quote: MarketQuoteDto? = null
)

@Serializable
data class MarketQuoteResponseDto(
    val quote: MarketQuoteDto? = null
)

@Serializable
data class CreateWatchlistItemRequest(
    val ticker: String,
    val exchange_operating_mic: String? = null
)

@Serializable
data class WatchlistItemDto(
    val id: String,
    val ticker: String,
    val name: String? = null,
    val category: String = "equity"
)

@Serializable
data class CreateWatchlistItemResponseDto(
    val watchlist_item: WatchlistItemDto
)

@Serializable
data class CreateTradeBody(
    val account_id: String,
    val type: String = "buy",
    val ticker: String,
    val qty: String,
    val price: String,
    val date: String,
    val fee: String = "0"
)

@Serializable
data class CreateTradeRequest(
    val trade: CreateTradeBody
)
