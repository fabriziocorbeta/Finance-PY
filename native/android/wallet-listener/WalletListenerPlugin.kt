package py.com.cdco.financespy.wallet

import android.content.Intent
import android.provider.Settings
import android.text.TextUtils
import com.getcapacitor.JSObject
import com.getcapacitor.Plugin
import com.getcapacitor.PluginCall
import com.getcapacitor.PluginMethod
import com.getcapacitor.annotation.CapacitorPlugin
import java.util.UUID
import java.util.concurrent.Executors

@CapacitorPlugin(name = "WalletListener")
class WalletListenerPlugin : Plugin() {
    private lateinit var store: PendingCaptureStore
    private val notificationExecutor = Executors.newSingleThreadExecutor()

    override fun load() {
        store = PendingCaptureStore(context)

        WalletNotificationListenerService.listener = { title, text ->
            handleNotification(title, text)
        }
    }

    private fun handleNotification(title: String, text: String) {
        notificationExecutor.execute {
            handleNotificationBlocking(title, text)
        }
    }

    private fun handleNotificationBlocking(title: String, text: String) {
        val purchase = PurchaseExtractor.extract(text) ?: return
        val accountId = AccountMapping.accountIdFor(purchase.cardText)
        val capturedAt = java.time.Instant.now().toString()

        val data = JSObject()
        data.put("merchant", title)
        data.put("amount", purchase.amount)
        data.put("cardText", purchase.cardText)

        if (accountId == null) {
            data.put("status", "unrecognized_card")
            notifyListeners("walletCapture", data)
            return
        }

        val capture = PendingCapture(
            id = UUID.randomUUID().toString(),
            capturedAt = capturedAt,
            rawText = text,
            accountId = accountId,
            amount = purchase.amount,
            merchant = title,
            item = purchase.cardText
        )

        val tokenResId = context.resources.getIdentifier("wallet_webhook_token", "string", context.packageName)
        if (tokenResId == 0) {
            store.add(capture)
            data.put("status", "token_missing")
            notifyListeners("walletCapture", data)
            return
        }
        val token = context.getString(tokenResId)
        val result = WebhookClient(token).post(capture)

        when (result) {
            is WebhookResult.Success -> {
                data.put("status", if (result.duplicate) "duplicate" else "created")
            }
            is WebhookResult.Failure -> {
                store.add(capture)
                data.put("status", "queued")
                data.put("error", result.error)
            }
        }
        notifyListeners("walletCapture", data)
    }

    @PluginMethod
    fun isListenerEnabled(call: PluginCall) {
        val flat = Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners")
        val enabled = !TextUtils.isEmpty(flat) && flat.contains(context.packageName)
        val ret = JSObject()
        ret.put("enabled", enabled)
        call.resolve(ret)
    }

    @PluginMethod
    fun requestPermission(call: PluginCall) {
        activity.startActivity(Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"))
        call.resolve()
    }

    @PluginMethod
    fun pendingCount(call: PluginCall) {
        val ret = JSObject()
        ret.put("count", store.readAll().size)
        call.resolve(ret)
    }
}
