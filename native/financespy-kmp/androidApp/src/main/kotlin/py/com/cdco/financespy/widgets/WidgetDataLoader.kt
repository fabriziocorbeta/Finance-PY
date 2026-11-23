package py.com.cdco.financespy.widgets

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import org.json.JSONObject
import py.com.cdco.financespy.cache.AndroidDashboardCache

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
}

object WidgetUpdater {
    fun updateAll(context: Context) {
        val appContext = context.applicationContext
        val manager = AppWidgetManager.getInstance(appContext)

        listOf(
            BalanceWidgetProvider::class.java,
            ExpensesWidgetProvider::class.java
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
