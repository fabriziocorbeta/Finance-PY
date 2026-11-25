package py.com.cdco.financespy.widgets

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.widget.RemoteViews
import py.com.cdco.financespy.MainActivity
import py.com.cdco.financespy.R
import py.com.cdco.financespy.utils.formatMoney
import kotlin.math.max
import kotlin.math.roundToInt

class BalanceWidgetProvider : AppWidgetProvider() {
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
        val layoutId = if (isWide) R.layout.widget_balance_wide else R.layout.widget_balance
        val views = RemoteViews(context.packageName, layoutId)

        if (snapshot != null) {
            val subtitle = if (snapshot.liquidAccountsCount > 0) {
                val label = if (snapshot.liquidAccountsCount == 1) "cuenta líquida" else "cuentas líquidas"
                "${snapshot.liquidAccountsCount} $label · ${snapshot.currency}"
            } else {
                "Sin cuentas líquidas · ${snapshot.currency}"
            }

            views.setTextViewText(R.id.widget_balance_title, "Líquido disponible")
            views.setTextViewText(
                R.id.widget_balance_amount,
                formatMoney(snapshot.availableAmount, snapshot.currency)
            )
            views.setTextViewText(R.id.widget_balance_subtitle, subtitle)

            if (isWide) {
                val liquid = max(0.0, snapshot.availableAmount)
                val liabilities = max(0.0, snapshot.liabilitiesAmount)
                val maxVal = max(liquid, liabilities).coerceAtLeast(1.0)
                val liquidPct = ((liquid / maxVal) * 100.0).roundToInt().coerceIn(0, 100)
                val liabPct = ((liabilities / maxVal) * 100.0).roundToInt().coerceIn(0, 100)

                views.setProgressBar(R.id.widget_balance_liquid_bar, 100, liquidPct, false)
                views.setTextViewText(
                    R.id.widget_balance_liquid_value,
                    formatMoney(liquid, snapshot.currency)
                )
                views.setProgressBar(R.id.widget_balance_liabilities_bar, 100, liabPct, false)
                views.setTextViewText(
                    R.id.widget_balance_liabilities_value,
                    if (liabilities > 0) "-${formatMoney(liabilities, snapshot.currency)}" else formatMoney(0.0, snapshot.currency)
                )
            } else {
                val barPct = if (snapshot.availableAmount > 0) 100 else 0
                views.setProgressBar(R.id.widget_balance_bar, 100, barPct, false)
            }
        } else {
            views.setTextViewText(R.id.widget_balance_title, "Líquido disponible")
            views.setTextViewText(R.id.widget_balance_amount, "₲ 0")
            views.setTextViewText(R.id.widget_balance_subtitle, "Abre FinancePY para sincronizar")
        }

        val launchIntent = Intent(
            Intent.ACTION_VIEW,
            android.net.Uri.parse("financespy://widgets/available"),
            context,
            MainActivity::class.java
        )
        val pendingIntent = PendingIntent.getActivity(
            context,
            widgetId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_balance_root, pendingIntent)

        appWidgetManager.updateAppWidget(widgetId, views)
    }
}
