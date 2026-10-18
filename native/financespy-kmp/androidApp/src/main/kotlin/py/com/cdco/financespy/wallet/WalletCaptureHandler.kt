package py.com.cdco.financespy.wallet

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import py.com.cdco.financespy.auth.AndroidTokenStorage
import java.time.Instant
import java.util.UUID
import java.util.concurrent.Executors
import kotlin.coroutines.resume

// Orquesta la captura completa (extraer -> mapear cuenta -> POST al webhook ->
// encolar si falla) usando solo un Context de Android.
// Necesario porque NotificationListenerService puede ser iniciado por el OS
// con el proceso en frío.
object WalletCaptureHandler {
    private val executor = Executors.newSingleThreadExecutor()

    // Optional native listener callback if UI or logger wants to observe capture events.
    var onResult: ((status: String, details: String) -> Unit)? = null

    fun handle(context: Context, packageName: String, title: String, text: String) {
        executor.execute {
            handleBlocking(context, packageName, title, text)
        }
    }

    // One notification can carry more than one transaction (see
    // ContinentalSmsExtractor -- bundled SMS notifications). Each extracted
    // Purchase is captured/posted independently: a dropped or queued one
    // must not block the others in the same notification.
    private fun handleBlocking(context: Context, packageName: String, title: String, text: String) {
        val extractors = BankNotificationExtractors.forPackage(packageName)
        val purchases = extractors.flatMap { it.extract(title, text) }
        if (purchases.isEmpty()) return

        val capturedAt = Instant.now().toString()
        val store = PendingCaptureStore(context)
        val token = runBlocking { AndroidTokenStorage(context).accessToken() }
        val device = "${Build.MANUFACTURER} ${Build.MODEL}".trim()
        val location = runBlocking { fetchLocationBestEffort(context) }

        purchases.forEach { purchase ->
            val accountId = AccountMapping.accountIdFor(context, purchase.cardText)
            if (accountId == null) {
                onResult?.invoke("unrecognized_card", purchase.cardText)
                return@forEach
            }

            val capture = PendingCapture(
                id = UUID.randomUUID().toString(),
                capturedAt = capturedAt,
                accountId = accountId,
                amount = purchase.amount,
                merchant = purchase.merchant,
                item = purchase.cardText,
                latitude = location?.first,
                longitude = location?.second,
                device = device,
                nature = purchase.nature
            )

            if (token.isNullOrBlank()) {
                store.add(capture)
                onResult?.invoke("token_missing", purchase.cardText)
                return@forEach
            }

            when (val result = WebhookClient(token).post(capture, rawText = text)) {
                is WebhookResult.Success -> {
                    onResult?.invoke(if (result.duplicate) "duplicate" else "created", purchase.cardText)
                }
                is WebhookResult.Failure -> {
                    store.add(capture)
                    onResult?.invoke("queued", result.error)
                }
            }
        }
    }

    // Reintenta las capturas encoladas. Corre en el mismo executor que add()
    // para que las mutaciones de PendingCaptureStore queden serializadas.
    fun retryPending(context: Context, callback: ((applied: Int) -> Unit)? = null) {
        executor.execute {
            val store = PendingCaptureStore(context)
            val token = runBlocking { AndroidTokenStorage(context).accessToken() }
            if (token.isNullOrBlank()) {
                callback?.invoke(0)
                return@execute
            }
            val client = WebhookClient(token)
            var applied = 0

            store.readAll().forEach { capture ->
                when (client.post(capture)) {
                    is WebhookResult.Success -> {
                        store.remove(capture.id)
                        applied++
                    }
                    is WebhookResult.Failure -> {
                        // se queda en la cola, se reintenta en la próxima llamada
                    }
                }
            }

            callback?.invoke(applied)
        }
    }

    // Best-effort device location for the current capture -- never blocks or
    // degrades the rest of the pipeline. Returns null (not an error) if the
    // user hasn't opted in via WalletLocationPreferences, hasn't granted
    // ACCESS_COARSE_LOCATION, or no fix arrives within the timeout.
    private const val LOCATION_TIMEOUT_MS = 4_000L

    private suspend fun fetchLocationBestEffort(context: Context): Pair<Double, Double>? {
        if (!WalletLocationPreferences(context).isLocationCaptureEnabled()) return null

        val hasPermission = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasPermission) return null

        return withTimeoutOrNull(LOCATION_TIMEOUT_MS) {
            suspendCancellableCoroutine { continuation ->
                val cancellationSource = CancellationTokenSource()
                continuation.invokeOnCancellation { cancellationSource.cancel() }

                val request = CurrentLocationRequest.Builder()
                    .setPriority(Priority.PRIORITY_BALANCED_POWER_ACCURACY)
                    .setDurationMillis(LOCATION_TIMEOUT_MS)
                    .build()

                try {
                    LocationServices.getFusedLocationProviderClient(context)
                        .getCurrentLocation(request, cancellationSource.token)
                        .addOnSuccessListener { location ->
                            val result = location?.let { it.latitude to it.longitude }
                            if (continuation.isActive) continuation.resume(result)
                        }
                        .addOnFailureListener {
                            if (continuation.isActive) continuation.resume(null)
                        }
                } catch (e: SecurityException) {
                    // Permission revoked between the check above and this call --
                    // rare race, treat the same as "no permission."
                    if (continuation.isActive) continuation.resume(null)
                }
            }
        }
    }
}
