package py.com.cdco.financespy.wallet

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.content.ContextCompat
import com.google.android.gms.location.CurrentLocationRequest
import com.google.android.gms.location.Granularity
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import com.google.android.gms.tasks.CancellationTokenSource
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.withLock
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
    private const val TAG = "WalletCaptureHandler"
    private val executor = Executors.newSingleThreadExecutor()

    // Optional native listener callback if UI or logger wants to observe capture events.
    var onResult: ((status: String, details: String) -> Unit)? = null

    fun handle(context: Context, packageName: String, title: String, text: String) {
        executor.execute {
            try {
                handleBlocking(context, packageName, title, text)
            } catch (t: Throwable) {
                Log.e(TAG, "Unhandled error in handleBlocking($packageName)", t)
            }
        }
    }

    // One notification can carry more than one transaction (see
    // ContinentalSmsExtractor -- bundled SMS notifications). Each extracted
    // Purchase is captured/posted independently: a dropped or queued one
    // must not block the others in the same notification.
    //
    // Write-ahead durability: every extracted purchase is persisted to
    // PendingCaptureStore BEFORE fetching GPS or making any network call.
    // Samsung One UI's FreecessController freezes background processes ~6s
    // after INotificationListener unfreezes them; persisting first guarantees
    // a transaction can NEVER be lost if the OS freezes/kills the process
    // mid-GPS or mid-HTTP. It is only removed from disk once the webhook
    // returns Success.
    private fun handleBlocking(context: Context, packageName: String, title: String, text: String) {
        val extractors = BankNotificationExtractors.forPackage(packageName)
        val purchases = extractors.flatMap { it.extract(title, text) }
        if (purchases.isEmpty()) return

        val capturedAt = Instant.now().toString()
        val store = PendingCaptureStore(context)
        val tokenStorage = AndroidTokenStorage(context)
        val device = "${Build.MANUFACTURER} ${Build.MODEL}".trim()

        // Step 1: Resolve accounts and persist every purchase to disk immediately
        // (milliseconds, before any GPS wait or network I/O).
        val persisted = purchases.map { purchase ->
            val accountId = AccountMapping.accountIdFor(context, purchase.cardText)
            val capture = PendingCapture(
                id = UUID.randomUUID().toString(),
                capturedAt = capturedAt,
                accountId = accountId,
                amount = purchase.amount,
                merchant = purchase.merchant,
                item = purchase.cardText,
                latitude = null,
                longitude = null,
                device = device,
                nature = purchase.nature
            )
            store.add(capture)
            capture
        }

        // Step 2: Best-effort GPS (short timeout so it finishes well before
        // Samsung's ~6s background freeze window). If a fix arrives, enrich the
        // already-persisted captures on disk.
        val location = runBlocking { fetchLocationBestEffort(context) }
        val enriched = if (location != null) {
            persisted.map { capture ->
                val withLoc = capture.copy(latitude = location.first, longitude = location.second)
                store.update(withLoc)
                withLoc
            }
        } else {
            persisted
        }

        // Step 3: Post each capture and remove from PendingCaptureStore only on Success.
        enriched.forEach { capture ->
            if (capture.accountId == null) {
                Log.w(TAG, "Unrecognized card for capture id=${capture.id}; kept in queue")
                onResult?.invoke("unrecognized_card", capture.item)
                return@forEach
            }

            when (val result = postWithTokenRefresh(tokenStorage, capture, rawText = text)) {
                is WebhookResult.Success -> {
                    store.remove(capture.id)
                    val status = if (result.duplicate) "duplicate" else "created"
                    Log.i(TAG, "Capture $status id=${capture.id}")
                    onResult?.invoke(status, capture.item)
                }
                is WebhookResult.Failure -> {
                    Log.w(TAG, "Capture id=${capture.id} kept in queue (unauthorized=${result.unauthorized})")
                    onResult?.invoke(if (result.error == "token_missing") "token_missing" else "queued", result.error)
                }
            }
        }
    }

    // Reintenta las capturas encoladas. Corre en el mismo executor que add()
    // para que las mutaciones de PendingCaptureStore queden serializadas.
    fun retryPending(context: Context, callback: ((applied: Int) -> Unit)? = null) {
        executor.execute {
            try {
                val store = PendingCaptureStore(context)
                val pending = store.readAll()
                if (pending.isEmpty()) {
                    callback?.invoke(0)
                    return@execute
                }

                val tokenStorage = AndroidTokenStorage(context)
                var applied = 0

                pending.forEach { capture ->
                    // A capture queued with no account (unrecognized card) gets
                    // its mapping retried here, not just its POST: the account it
                    // belongs to may have been renamed or created since. Still
                    // unresolved means leave it queued -- never drop it.
                    val resolved = capture.accountId
                        ?: AccountMapping.accountIdFor(context, capture.item)
                        ?: run {
                            Log.w(TAG, "Retry skipped (unrecognized card) for capture id=${capture.id}")
                            return@forEach
                        }

                    when (val result = postWithTokenRefresh(tokenStorage, capture.copy(accountId = resolved))) {
                        is WebhookResult.Success -> {
                            store.remove(capture.id)
                            applied++
                            Log.i(TAG, "Retry succeeded (${if (result.duplicate) "duplicate" else "created"}) id=${capture.id}")
                        }
                        is WebhookResult.Failure -> {
                            Log.w(TAG, "Retry failed for capture id=${capture.id} (unauthorized=${result.unauthorized})")
                            // se queda en la cola, se reintenta en la próxima llamada
                        }
                    }
                }

                callback?.invoke(applied)
            } catch (t: Throwable) {
                Log.e(TAG, "Unhandled error in retryPending", t)
                callback?.invoke(0)
            }
        }
    }

    // Posts a capture and transparently handles expired OAuth access tokens
    // (Doorkeeper TTL = 2h). NotificationListenerService fires in the
    // background long after the last foreground session, and MainActivity's
    // onResume() calls retryPending() before ApiClient refreshes its token —
    // without refreshing here, captures got stuck with 401 Unauthorized.
    private fun postWithTokenRefresh(
        tokenStorage: AndroidTokenStorage,
        capture: PendingCapture,
        rawText: String? = null
    ): WebhookResult {
        var token = runBlocking { tokenStorage.accessToken() }
        if (token.isNullOrBlank()) {
            token = refreshAndSaveToken(tokenStorage) ?: return WebhookResult.Failure("token_missing")
        }

        val firstAttempt = WebhookClient(token).post(capture, rawText = rawText)
        if (firstAttempt !is WebhookResult.Failure || !firstAttempt.unauthorized) {
            return firstAttempt
        }

        // Before consuming the refresh_token, check if ApiClient already
        // refreshed the access_token concurrently on another thread.
        val latestStored = runBlocking { tokenStorage.accessToken() }
        val retryToken = if (!latestStored.isNullOrBlank() && latestStored != token) {
            Log.i(TAG, "Detected concurrently refreshed access token; retrying webhook")
            latestStored
        } else {
            refreshAndSaveToken(tokenStorage, failedAccessToken = token) ?: return firstAttempt
        }

        return WebhookClient(retryToken).post(capture, rawText = rawText)
    }

    private fun refreshAndSaveToken(tokenStorage: AndroidTokenStorage, failedAccessToken: String? = null): String? {
        return runBlocking {
            py.com.cdco.financespy.auth.TokenRefreshLock.mutex.withLock {
                // Re-check inside shared mutex: ApiClient may have already rotated tokens.
                val currentAccess = tokenStorage.accessToken()
                if (!currentAccess.isNullOrBlank() && failedAccessToken != null && currentAccess != failedAccessToken) {
                    return@withLock currentAccess
                }

                val refreshToken = tokenStorage.refreshToken() ?: return@withLock null
                val refreshed = WebhookClient.refreshAccessToken(refreshToken) ?: run {
                    Log.w(TAG, "OAuth token refresh failed")
                    return@withLock null
                }
                tokenStorage.save(refreshed.first, refreshed.second)
                Log.i(TAG, "OAuth access token refreshed successfully for webhook")
                refreshed.first
            }
        }
    }

    // Best-effort device location for the current capture -- never blocks or
    // degrades the rest of the pipeline. Returns null (not an error) if the
    // user hasn't opted in via WalletLocationPreferences, hasn't granted
    // location permission, or no fix arrives within the timeout.
    // When the user granted ACCESS_FINE_LOCATION, always enforce GRANULARITY_FINE,
    // PRIORITY_HIGH_ACCURACY, and a fresh fix (maxUpdateAgeMillis) so Android
    // never silently downgrades to a stale or coarse cell-tower location.
    private const val LOCATION_TIMEOUT_FINE_MS = 3_000L
    private const val LOCATION_TIMEOUT_COARSE_MS = 2_000L
    private const val LOCATION_MAX_AGE_FINE_MS = 30_000L

    private suspend fun fetchLocationBestEffort(context: Context): Pair<Double, Double>? {
        if (!WalletLocationPreferences(context).isLocationCaptureEnabled()) return null

        val hasFine = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val hasCoarse = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        if (!hasFine && !hasCoarse) return null

        val timeoutMs = if (hasFine) LOCATION_TIMEOUT_FINE_MS else LOCATION_TIMEOUT_COARSE_MS
        val requestBuilder = CurrentLocationRequest.Builder()
            .setDurationMillis(timeoutMs)

        if (hasFine) {
            requestBuilder
                .setPriority(Priority.PRIORITY_HIGH_ACCURACY)
                .setGranularity(Granularity.GRANULARITY_FINE)
                .setMaxUpdateAgeMillis(LOCATION_MAX_AGE_FINE_MS)
        } else {
            requestBuilder
                .setPriority(Priority.PRIORITY_BALANCED_POWER_ACCURACY)
                .setGranularity(Granularity.GRANULARITY_COARSE)
        }

        val request = requestBuilder.build()

        return withTimeoutOrNull(timeoutMs) {
            suspendCancellableCoroutine { continuation ->
                val cancellationSource = CancellationTokenSource()
                continuation.invokeOnCancellation { cancellationSource.cancel() }

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
