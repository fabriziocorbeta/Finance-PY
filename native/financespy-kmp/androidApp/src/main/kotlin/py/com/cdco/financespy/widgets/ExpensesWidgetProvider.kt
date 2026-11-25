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

class ExpensesWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val snapshot = WidgetDataLoader.loadSnapshot(context)
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
        val snapshot = WidgetDataLoader.loadSnapshot(context)
        updateWidget(context, appWidgetManager, appWidgetId, newOptions, snapshot)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        options: Bundle,
        snapshot: WidgetSnapshot?
    ) {
        val minWidthDp = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 140)
        val isWide = minWidthDp >= 220
        val layoutId = if (isWide) R.layout.widget_expenses_wide else R.layout.widget_expenses
        val views = RemoteViews(context.packageName, layoutId)

        val rowIds = if (isWide) {
            listOf(R.id.widget_expenses_row_1, R.id.widget_expenses_row_2, R.id.widget_expenses_row_3)
        } else {
            listOf(R.id.widget_expenses_row_1, R.id.widget_expenses_row_2)
        }

        if (snapshot != null) {
            views.setTextViewText(R.id.widget_expenses_period, snapshot.periodLabel)
            views.setTextViewText(
                R.id.widget_expenses_total,
                formatMoney(snapshot.outflowsTotal, snapshot.outflowsCurrency)
            )

            if (snapshot.topCategories.isEmpty()) {
                views.setTextViewText(R.id.widget_expenses_row_1, "Sin gastos registrados")
                views.setViewVisibility(R.id.widget_expenses_row_1, View.VISIBLE)
                rowIds.drop(1).forEach { views.setViewVisibility(it, View.GONE) }
            } else {
                rowIds.forEachIndexed { index, viewId ->
                    val cat = snapshot.topCategories.getOrNull(index)
                    if (cat != null) {
                        val pct = cat.percentage?.let { " (${it.toInt()}%)" } ?: ""
                        val line = "${cat.name}: ${formatMoney(cat.amount, cat.currency)}$pct"
                        views.setTextViewText(viewId, line)
                        views.setViewVisibility(viewId, View.VISIBLE)
                    } else {
                        views.setViewVisibility(viewId, View.GONE)
                    }
                }
            }
        } else {
            views.setTextViewText(R.id.widget_expenses_period, "FinancePY")
            views.setTextViewText(R.id.widget_expenses_total, "₲ 0")
            views.setTextViewText(R.id.widget_expenses_row_1, "Abre FinancePY para sincronizar")
            views.setViewVisibility(R.id.widget_expenses_row_1, View.VISIBLE)
            rowIds.drop(1).forEach { views.setViewVisibility(it, View.GONE) }
        }

        val launchIntent = Intent(
            Intent.ACTION_VIEW,
            android.net.Uri.parse("financespy://widgets/recent_expenses"),
            context,
            MainActivity::class.java
        )
        val pendingIntent = PendingIntent.getActivity(
            context,
            widgetId + 10_000,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_expenses_root, pendingIntent)

        appWidgetManager.updateAppWidget(widgetId, views)
    }
}
