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
import py.com.cdco.financespy.utils.formatMoney

class PortfolioWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val snapshot = WidgetDataLoader.loadPortfolioSnapshot(context)
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
        val snapshot = WidgetDataLoader.loadPortfolioSnapshot(context)
        updateWidget(context, appWidgetManager, appWidgetId, newOptions, snapshot)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        options: Bundle,
        snapshot: PortfolioWidgetSnapshot?
    ) {
        val minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 140)
        val isWide = minWidthDp >= 220
        val layoutId = if (isWide) R.layout.widget_portfolio_wide else R.layout.widget_portfolio
        val views = RemoteViews(context.packageName, layoutId)

        if (snapshot != null) {
            views.setTextViewText(
                R.id.widget_portfolio_value,
                formatMoney(snapshot.portfolioValue, snapshot.currency)
            )

            val retText = snapshot.unrealizedPercentFormatted ?: "0.0%"
            val pillBg = when {
                snapshot.unrealizedPercentFormatted == null -> R.drawable.widget_pill_neutral
                snapshot.isPositive -> R.drawable.widget_pill_green
                else -> R.drawable.widget_pill_red
            }
            views.setTextViewText(R.id.widget_portfolio_return_pill, retText)
            views.setInt(R.id.widget_portfolio_return_pill, "setBackgroundResource", pillBg)

            if (isWide) {
                val rowIds = listOf(
                    R.id.widget_portfolio_row_1,
                    R.id.widget_portfolio_row_2,
                    R.id.widget_portfolio_row_3
                )
                val tickerIds = listOf(
                    R.id.widget_portfolio_ticker_1,
                    R.id.widget_portfolio_ticker_2,
                    R.id.widget_portfolio_ticker_3
                )
                val valIds = listOf(
                    R.id.widget_portfolio_val_1,
                    R.id.widget_portfolio_val_2,
                    R.id.widget_portfolio_val_3
                )
                val pillIds = listOf(
                    R.id.widget_portfolio_pill_1,
                    R.id.widget_portfolio_pill_2,
                    R.id.widget_portfolio_pill_3
                )

                if (snapshot.topHoldings.isEmpty()) {
                    views.setViewVisibility(R.id.widget_portfolio_empty, View.VISIBLE)
                    rowIds.forEach { views.setViewVisibility(it, View.GONE) }
                } else {
                    views.setViewVisibility(R.id.widget_portfolio_empty, View.GONE)
                    rowIds.forEachIndexed { index, rowId ->
                        val h = snapshot.topHoldings.getOrNull(index)
                        if (h != null) {
                            views.setViewVisibility(rowId, View.VISIBLE)
                            views.setTextViewText(tickerIds[index], h.ticker)
                            views.setTextViewText(valIds[index], formatMoney(h.value, h.currency))
                            val hPct = h.returnPercentFormatted ?: "—"
                            val hBg = when {
                                h.returnPercentFormatted == null -> R.drawable.widget_pill_neutral
                                h.isPositive -> R.drawable.widget_pill_green
                                else -> R.drawable.widget_pill_red
                            }
                            views.setTextViewText(pillIds[index], hPct)
                            views.setInt(pillIds[index], "setBackgroundResource", hBg)
                        } else {
                            views.setViewVisibility(rowId, View.GONE)
                        }
                    }
                }
            } else {
                val h1 = snapshot.topHoldings.getOrNull(0)
                val h2 = snapshot.topHoldings.getOrNull(1)
                if (h1 != null) {
                    val pct1 = h1.returnPercentFormatted?.let { " ($it)" } ?: ""
                    views.setTextViewText(
                        R.id.widget_portfolio_holding_1,
                        "${h1.ticker}: ${formatMoney(h1.value, h1.currency)}$pct1"
                    )
                    views.setViewVisibility(R.id.widget_portfolio_holding_1, View.VISIBLE)
                } else {
                    views.setTextViewText(R.id.widget_portfolio_holding_1, "Sin posiciones activas")
                    views.setViewVisibility(R.id.widget_portfolio_holding_1, View.VISIBLE)
                }

                if (h2 != null) {
                    val pct2 = h2.returnPercentFormatted?.let { " ($it)" } ?: ""
                    views.setTextViewText(
                        R.id.widget_portfolio_holding_2,
                        "${h2.ticker}: ${formatMoney(h2.value, h2.currency)}$pct2"
                    )
                    views.setViewVisibility(R.id.widget_portfolio_holding_2, View.VISIBLE)
                } else {
                    views.setViewVisibility(R.id.widget_portfolio_holding_2, View.GONE)
                }
            }
        } else {
            views.setTextViewText(R.id.widget_portfolio_value, "₲ 0")
            views.setTextViewText(R.id.widget_portfolio_return_pill, "—")
            views.setInt(R.id.widget_portfolio_return_pill, "setBackgroundResource", R.drawable.widget_pill_neutral)
            if (isWide) {
                views.setViewVisibility(R.id.widget_portfolio_empty, View.VISIBLE)
                listOf(
                    R.id.widget_portfolio_row_1,
                    R.id.widget_portfolio_row_2,
                    R.id.widget_portfolio_row_3
                ).forEach { views.setViewVisibility(it, View.GONE) }
            } else {
                views.setTextViewText(R.id.widget_portfolio_holding_1, "Abre FinancePY para sincronizar")
                views.setViewVisibility(R.id.widget_portfolio_holding_2, View.GONE)
            }
        }

        val launchIntent = Intent(context, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            context,
            widgetId + 30_000,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_portfolio_root, pendingIntent)

        appWidgetManager.updateAppWidget(widgetId, views)
    }
}
