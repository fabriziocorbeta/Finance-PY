package py.com.cdco.financespy.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import py.com.cdco.financespy.MainActivity
import py.com.cdco.financespy.R
import java.util.Locale

class MarketWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val snapshot = WidgetDataLoader.loadMarketSnapshot(context)
        for (widgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(widgetId)
            updateWidget(context, appWidgetManager, widgetId, options, snapshot)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val snapshot = WidgetDataLoader.loadMarketSnapshot(context)
        updateWidget(context, appWidgetManager, appWidgetId, newOptions, snapshot)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        options: Bundle,
        snapshot: MarketWidgetSnapshot?
    ) {
        val minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 140)
        val isWide = minWidthDp >= 220
        val layoutId = if (isWide) R.layout.widget_market_wide else R.layout.widget_market
        val views = RemoteViews(context.packageName, layoutId)

        val rowIds = if (isWide) {
            listOf(
                R.id.widget_market_row_1,
                R.id.widget_market_row_2,
                R.id.widget_market_row_3,
                R.id.widget_market_row_4
            )
        } else {
            listOf(
                R.id.widget_market_row_1,
                R.id.widget_market_row_2,
                R.id.widget_market_row_3
            )
        }

        val symbolIds = if (isWide) {
            listOf(
                R.id.widget_market_symbol_1,
                R.id.widget_market_symbol_2,
                R.id.widget_market_symbol_3,
                R.id.widget_market_symbol_4
            )
        } else {
            listOf(
                R.id.widget_market_symbol_1,
                R.id.widget_market_symbol_2,
                R.id.widget_market_symbol_3
            )
        }

        val nameIds = listOf(
            R.id.widget_market_name_1,
            R.id.widget_market_name_2,
            R.id.widget_market_name_3,
            R.id.widget_market_name_4
        )

        val priceIds = if (isWide) {
            listOf(
                R.id.widget_market_price_1,
                R.id.widget_market_price_2,
                R.id.widget_market_price_3,
                R.id.widget_market_price_4
            )
        } else {
            listOf(
                R.id.widget_market_price_1,
                R.id.widget_market_price_2,
                R.id.widget_market_price_3
            )
        }

        val pillIds = if (isWide) {
            listOf(
                R.id.widget_market_pill_1,
                R.id.widget_market_pill_2,
                R.id.widget_market_pill_3,
                R.id.widget_market_pill_4
            )
        } else {
            listOf(
                R.id.widget_market_pill_1,
                R.id.widget_market_pill_2,
                R.id.widget_market_pill_3
            )
        }

        val items = snapshot?.combinedDisplayItems ?: emptyList()
        if (items.isEmpty()) {
            views.setViewVisibility(R.id.widget_market_empty, View.VISIBLE)
            rowIds.forEach { views.setViewVisibility(it, View.GONE) }
        } else {
            views.setViewVisibility(R.id.widget_market_empty, View.GONE)
            rowIds.forEachIndexed { index, rowId ->
                val item = items.getOrNull(index)
                if (item != null) {
                    views.setViewVisibility(rowId, View.VISIBLE)
                    views.setTextViewText(symbolIds[index], item.ticker)
                    if (isWide) {
                        views.setTextViewText(nameIds[index], item.name)
                    }
                    views.setTextViewText(priceIds[index], formatMarketPrice(item.currentPrice))

                    val pct = item.changePercent
                    val pillText = if (pct != null) {
                        val sign = if (pct >= 0) "+" else ""
                        String.format(Locale.US, "%s%.2f%%", sign, pct)
                    } else {
                        "—"
                    }
                    val pillBg = when {
                        pct == null -> R.drawable.widget_pill_neutral
                        pct >= 0 -> R.drawable.widget_pill_green
                        else -> R.drawable.widget_pill_red
                    }
                    views.setTextViewText(pillIds[index], pillText)
                    views.setInt(pillIds[index], "setBackgroundResource", pillBg)
                } else {
                    views.setViewVisibility(rowId, View.GONE)
                }
            }
        }

        val launchIntent = Intent(
            Intent.ACTION_VIEW,
            android.net.Uri.parse("financespy://widgets/investments"),
            context,
            MainActivity::class.java
        )
        val pendingIntent = PendingIntent.getActivity(
            context,
            widgetId + 20_000,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_market_root, pendingIntent)

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun formatMarketPrice(price: Double?): String {
        if (price == null) return "—"
        return if (price >= 1000.0) {
            String.format(Locale.US, "%,.2f", price)
        } else {
            String.format(Locale.US, "%.2f", price)
        }
    }
}
