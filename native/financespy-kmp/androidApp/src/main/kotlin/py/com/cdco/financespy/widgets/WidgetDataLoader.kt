package py.com.cdco.financespy.widgets

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject
import py.com.cdco.financespy.cache.AndroidDashboardCache
import py.com.cdco.financespy.cache.AndroidOfflineStore

internal data class WidgetCategoryItem(
    val name: String,
    val amount: Double,
    val currency: String,
    val percentage: Double?
)

internal data class WidgetSnapshot(
    val currency: String,
    val periodLabel: String,
    val availableAmount: Double,
    val liquidAccountsCount: Int,
    val liabilitiesAmount: Double,
    val netWorthAmount: Double,
    val netWorthTrendPercent: String?,
    val outflowsTotal: Double,
    val outflowsCurrency: String,
    val topCategories: List<WidgetCategoryItem>
)

internal data class MarketQuoteItem(
    val ticker: String,
    val name: String,
    val currency: String,
    val currentPrice: Double?,
    val change: Double?,
    val changePercent: Double?
)

internal data class MarketWidgetSnapshot(
    val indices: List<MarketQuoteItem>,
    val watchlist: List<MarketQuoteItem>,
    val holdings: List<MarketQuoteItem>
) {
    val combinedDisplayItems: List<MarketQuoteItem>
        get() {
            val seen = HashSet<String>()
            val result = mutableListOf<MarketQuoteItem>()
            // Prioritize user's watchlist first (Yahoo Finance style), then major indices
            val ordered = watchlist + indices + holdings
            for (item in ordered) {
                val key = item.ticker.uppercase()
                if (key !in seen) {
                    seen.add(key)
                    result.add(item)
                }
            }
            return result
        }
}

internal data class PortfolioHoldingItem(
    val ticker: String,
    val name: String,
    val value: Double,
    val currency: String,
    val returnPercentFormatted: String?,
    val isPositive: Boolean
)

internal data class PortfolioWidgetSnapshot(
    val portfolioValue: Double,
    val currency: String,
    val unrealizedValue: Double?,
    val unrealizedPercentFormatted: String?,
    val isPositive: Boolean,
    val topHoldings: List<PortfolioHoldingItem>
)

internal object WidgetDataLoader {
    private val fallbackPeriods = listOf<String?>(null, "30d", "this_month", "last_30_days", "90d", "1y")

    fun loadSnapshot(context: Context): WidgetSnapshot? {
        return try {
            val cache = AndroidDashboardCache(context.applicationContext)
            val raw = fallbackPeriods.firstNotNullOfOrNull { period ->
                cache.load(period)?.takeIf { it.isNotBlank() }
            } ?: return null

            val root = JSONObject(raw)
            val currency = root.optString("currency", "PYG").ifBlank { "PYG" }
            val periodLabel = root.optJSONObject("period")?.optString("label", "")?.ifBlank { null } ?: "Período"

            val netWorthObj = root.optJSONObject("net_worth")
            val netWorthAmount = netWorthObj?.optDouble("amount", 0.0) ?: 0.0
            val trendPercent = netWorthObj?.optJSONObject("trend")
                ?.optString("percent_formatted", "")
                ?.ifBlank { null }

            var liquidTotal = 0.0
            var liquidCount = 0
            var liabilitiesTotal = 0.0

            val groups = root.optJSONObject("balance_sheet")?.optJSONArray("classification_groups")
            if (groups != null) {
                for (i in 0 until groups.length()) {
                    val cg = groups.optJSONObject(i) ?: continue
                    val classification = cg.optString("classification", "").lowercase()
                    if (classification == "liability") {
                        liabilitiesTotal += kotlin.math.abs(cg.optDouble("total", 0.0))
                        continue
                    }

                    val accountGroups = cg.optJSONArray("account_groups") ?: continue
                    for (j in 0 until accountGroups.length()) {
                        val ag = accountGroups.optJSONObject(j) ?: continue
                        val key = ag.optString("key", "").lowercase()
                        val name = ag.optString("name", "").lowercase()
                        val isLiquid = key in setOf("depository", "cash", "checking", "savings") ||
                            name.contains("efectivo") || name.contains("banco") || name.contains("cash") ||
                            name.contains("depósito") || name.contains("deposito")
                        if (isLiquid) {
                            liquidTotal += ag.optDouble("total", 0.0)
                            liquidCount += ag.optJSONArray("accounts")?.length() ?: 0
                        }
                    }
                }
            }

            val availableAmount = liquidTotal

            val outflowsObj = root.optJSONObject("outflows_donut")
            val outflowsTotal = outflowsObj?.optDouble("total", 0.0) ?: 0.0
            val outflowsCurrency = outflowsObj?.optString("currency", currency)?.ifBlank { currency } ?: currency
            val categories = mutableListOf<WidgetCategoryItem>()
            val catArray = outflowsObj?.optJSONArray("categories")
            if (catArray != null) {
                for (i in 0 until minOf(catArray.length(), 3)) {
                    val cat = catArray.optJSONObject(i) ?: continue
                    val name = cat.optString("name", "")
                    if (name.isBlank()) continue
                    val amount = cat.optDouble("amount", 0.0)
                    val catCurrency = cat.optString("currency", outflowsCurrency).ifBlank { outflowsCurrency }
                    val pct = if (cat.has("percentage") && !cat.isNull("percentage")) {
                        cat.optDouble("percentage")
                    } else {
                        null
                    }
                    categories.add(WidgetCategoryItem(name, amount, catCurrency, pct))
                }
            }

            WidgetSnapshot(
                currency = currency,
                periodLabel = periodLabel,
                availableAmount = availableAmount,
                liquidAccountsCount = liquidCount,
                liabilitiesAmount = liabilitiesTotal,
                netWorthAmount = netWorthAmount,
                netWorthTrendPercent = trendPercent,
                outflowsTotal = outflowsTotal,
                outflowsCurrency = outflowsCurrency,
                topCategories = categories
            )
        } catch (_: Throwable) {
            null
        }
    }

    fun loadMarketSnapshot(context: Context): MarketWidgetSnapshot? {
        return try {
            val raw = AndroidOfflineStore(context.applicationContext)
                .get("cache_market_tracker")
                ?.takeIf { it.isNotBlank() }
                ?: return null
            val root = JSONObject(raw)
            MarketWidgetSnapshot(
                indices = parseQuoteArray(root.optJSONArray("index_quotes")),
                watchlist = parseQuoteArray(root.optJSONArray("watchlist_quotes")),
                holdings = parseQuoteArray(root.optJSONArray("holding_quotes"))
            )
        } catch (_: Throwable) {
            null
        }
    }

    fun loadPortfolioSnapshot(context: Context): PortfolioWidgetSnapshot? {
        return try {
            val cache = AndroidDashboardCache(context.applicationContext)
            val raw = fallbackPeriods.firstNotNullOfOrNull { period ->
                cache.load(period)?.takeIf { it.isNotBlank() }
            } ?: return null

            val root = JSONObject(raw)
            val currency = root.optString("currency", "PYG").ifBlank { "PYG" }
            val summary = root.optJSONObject("investment_summary") ?: return null
            val invCurrency = summary.optString("currency", currency).ifBlank { currency }
            val portfolioValue = summary.optDouble("portfolio_value", 0.0)

            val gains = summary.optJSONObject("unrealized_gains")
            val unrealizedValue = if (gains != null && gains.has("value") && !gains.isNull("value")) {
                gains.optDouble("value")
            } else {
                null
            }
            val unrealizedPct = gains?.optString("percent_formatted", "")?.ifBlank { null }
            val isPositive = (unrealizedValue ?: 0.0) >= 0.0

            val holdingsList = mutableListOf<PortfolioHoldingItem>()
            val arr = summary.optJSONArray("top_holdings")
            if (arr != null) {
                for (i in 0 until minOf(arr.length(), 4)) {
                    val h = arr.optJSONObject(i) ?: continue
                    val ticker = h.optString("ticker", "").trim()
                    if (ticker.isEmpty()) continue
                    val name = h.optString("name", ticker).ifBlank { ticker }
                    val value = h.optDouble("value", 0.0)
                    val hCurrency = h.optString("currency", invCurrency).ifBlank { invCurrency }
                    val retPct = h.optString("return_percent_formatted", "").ifBlank { null }
                    val retPositive = !(retPct?.trim()?.startsWith("-") ?: false)
                    holdingsList.add(
                        PortfolioHoldingItem(
                            ticker = ticker,
                            name = name,
                            value = value,
                            currency = hCurrency,
                            returnPercentFormatted = retPct,
                            isPositive = retPositive
                        )
                    )
                }
            }

            PortfolioWidgetSnapshot(
                portfolioValue = portfolioValue,
                currency = invCurrency,
                unrealizedValue = unrealizedValue,
                unrealizedPercentFormatted = unrealizedPct,
                isPositive = isPositive,
                topHoldings = holdingsList
            )
        } catch (_: Throwable) {
            null
        }
    }

    private fun parseQuoteArray(arr: JSONArray?): List<MarketQuoteItem> {
        if (arr == null) return emptyList()
        val list = mutableListOf<MarketQuoteItem>()
        for (i in 0 until arr.length()) {
            val obj = arr.optJSONObject(i) ?: continue
            val ticker = obj.optString("ticker", "").trim()
            if (ticker.isEmpty()) continue
            val name = obj.optString("name", ticker).ifBlank { ticker }
            val currency = obj.optString("currency", "USD").ifBlank { "USD" }
            val currentPrice = if (obj.has("current_price") && !obj.isNull("current_price")) {
                obj.optDouble("current_price")
            } else {
                null
            }
            val change = if (obj.has("change") && !obj.isNull("change")) {
                obj.optDouble("change")
            } else {
                null
            }
            val changePct = if (obj.has("change_percent") && !obj.isNull("change_percent")) {
                obj.optDouble("change_percent")
            } else {
                null
            }
            list.add(MarketQuoteItem(ticker, name, currency, currentPrice, change, changePct))
        }
        return list
    }
}

object WidgetUpdater {
    fun updateAll(context: Context) {
        val appContext = context.applicationContext
        val manager = AppWidgetManager.getInstance(appContext)

        listOf(
            BalanceWidgetProvider::class.java,
            ExpensesWidgetProvider::class.java,
            MarketWidgetProvider::class.java,
            PortfolioWidgetProvider::class.java
        ).forEach { widgetClass ->
            val ids = manager.getAppWidgetIds(ComponentName(appContext, widgetClass))
            if (ids.isNotEmpty()) {
                val intent = Intent(appContext, widgetClass).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                appContext.sendBroadcast(intent)
            }
        }
    }
}
