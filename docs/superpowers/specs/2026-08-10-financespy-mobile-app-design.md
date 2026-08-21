# FinancePY Mobile App (React Native) — Design Spec

**Date:** 2026-08-10
**Project:** FinancePY (repo `cd-co-erp`, branch `main`)
**Status:** Approved, ready for implementation plan

## Purpose

Replace the Tasker/MacroDroid-based Google Wallet purchase-capture automation with a real native mobile app that (a) captures Google Wallet PYG purchase notifications on Android automatically, without any third-party automation app, and (b) is architected to extend to iOS in the future for the rest of the app's functionality (login, viewing transactions), even though the notification-capture feature itself is Android-only by platform limitation.

This replaces the third-party-app plan explored earlier in the same investigation (MacroDroid) after Fabrizio explicitly requested a first-party native app instead, integrating "completely natively with FinancePY."

## Context (how we got here)

1. The Google Wallet purchase webhook (`POST /webhooks/android_purchase`, spec `2026-07-28-android-purchase-webhook-design.md`) was built and deployed, intended to be fed by Tasker or MacroDroid reading notifications and POSTing to it.
2. Two real bugs were found and fixed in that webhook this session (commits `5b1daba`, `f20fa8d`): a missing `ANDROID_WEBHOOK_TOKEN` after the VM→notebook migration, and incorrect thousands-separator parsing — the real Google Wallet PYG notification format is comma-thousands (`"PYG112,000 con GNB GOOGLE ••6536"`), confirmed against a real captured notification.
3. Fabrizio then asked for the automation to be "100% native," ruling out Tasker/MacroDroid. Investigated Samsung "Modos y Rutinas" (Bixby Routines) directly against the real device: its notification trigger only supports boolean keyword filtering, never exposes notification text as a usable variable, and its action catalog has no HTTP/webhook action at all. Confirmed with an independent Perplexity investigation reaching the same conclusion. Also investigated Google AI Studio's new (May 2026) native Android app builder — ruled out because it explicitly restricts generated apps to a single-activity/single-module architecture with no server component, which cannot accommodate `NotificationListenerService` (a background `Service`, not an activity), and because it is Android-only, which would abandon the future-iOS goal.
4. Conclusion: **no native OS configuration path exists on Android for this**. The only ways to read another app's notification text and act on it are (a) a third-party automation app, or (b) writing your own app using `NotificationListenerService`. Fabrizio chose (b).

## Non-goals (explicit YAGNI for this spec)

- No feature parity with the FinancePY web UI. This is a capture-and-confirm tool, not a full mobile client.
- No budgets, goals, investments, settings, categorization, or editing of transactions in the app.
- No iOS build in this phase. The app is structured to support iOS later (shared business logic, OAuth flow that works identically on both platforms), but only Android is built, tested, and shipped now. The notification-capture feature will never exist on iOS — this is a hard Apple platform restriction, not a scoping choice (see "iOS notes" below).
- No Play Store / TestFlight distribution. Sideload only (signed release APK via adb), same distribution model already used for `financespy-twa`.
- No new backend idempotency mechanism. The app reuses the existing, already-tested webhook (`AndroidPurchase::WebhookProcessor`) for the capture write path instead of building equivalent idempotency into the OAuth-authenticated `api/v1/transactions#create` endpoint (which does not currently accept `source`/`external_id` params).
- No automated E2E testing (Detox/Maestro). This is a personal, single-user app; manual QA on-device is sufficient.

## Architecture

**Framework:** React Native (bare CLI, not Expo) — chosen for full control over the custom native Android module without fighting a managed workflow, and because the developer already has a working Android Studio/Gradle toolchain from the `financespy-twa` project.

Three components, each with one job:

### 1. Native module — `NotificationListenerModule` (Kotlin, Android-only)

- Declares `android.service.notification.NotificationListenerService` in the manifest, requesting `BIND_NOTIFICATION_LISTENER_SERVICE`.
- On first run (or when the app detects the permission isn't granted), deep-links to `Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS` for the user to enable manually — this permission cannot be requested via the standard runtime dialog.
- Filters `onNotificationPosted` to `sbn.getPackageName() == "com.google.android.apps.walletnfcrel"` before touching content, to avoid processing unrelated notifications by config error.
- Emits the raw `{packageName, title, text}` to the JS layer via React Native's `DeviceEventEmitter`. No parsing or business logic lives here — it's a thin bridge.
- Does not exist on iOS. No no-op stub is needed; the JS layer simply never receives these events on iOS, and the "capture" feature surfaces as absent there (see iOS notes).

### 2. JS/TS — extraction, mapping, and capture write path

- Receives the raw notification event, applies the confirmed extraction regex: `PYG([\d,]+) con (.+)`.
- Maps the extracted card descriptor to a fixed `account_id` via a 4-entry lookup table (same mapping validated for the MacroDroid design):

  | Card descriptor substring | account_id |
  |---|---|
  | `Ueno` | `74fa6687-bbf7-45d2-aa71-f06bca3b2013` |
  | `Amex` | `d47f5223-a988-46f5-9bc5-beefc4c7fefd` |
  | `CLASICA` | `952d06b3-f915-4cf1-b4c2-952fb131f2be` |
  | `GNB` | `43d84b14-b3be-44a9-be37-7ec1ae4661f2` |

  Unmatched descriptor → local notification "Tarjeta no reconocida: <texto>", nothing is sent to the server (same defensive behavior designed for the MacroDroid plan — never guess an account).
- POSTs to the existing `/webhooks/android_purchase` endpoint using the static bearer token, retrieved from Android Keystore via `react-native-keychain` — never stored in plain JS/AsyncStorage, since a JS bundle is trivially extractable from an APK.
- This path intentionally does **not** use the app's own OAuth session. It reuses the same static-token webhook that Tasker/MacroDroid would have used, because that endpoint already has correct, tested idempotency (`SHA256(amount|timestamp|merchant)` unique index) that the OAuth-authenticated `api/v1/transactions#create` endpoint does not currently have. Unifying both under one auth model was considered and explicitly deferred (YAGNI) — see Non-goals.

### 3. JS/TS — auth and read-only confirmation view

- Login via Doorkeeper OAuth2, Authorization Code + PKCE (`force_pkce` is already enabled server-side), using `react-native-app-auth` for the in-app browser flow (Custom Tabs on Android).
- Backend change required: the existing shared `Doorkeeper::Application` is named `"Sure Mobile"` with `redirect_uri: "sureapp://oauth/callback"` — both reference the forbidden upstream brand name. Rename to `"FinancePY Mobile"` / `financespy://oauth/callback` as part of this implementation. `confidential: false` is already correct for a PKCE public client.
- Tokens (`access_token`, `refresh_token`) stored in Android Keystore via `react-native-keychain`, never in plain `AsyncStorage`.
- A single read-only screen lists the most recent transactions via `GET /api/v1/transactions?per_page=20`, to let Fabrizio confirm a capture landed correctly without opening the web app. No editing, no categorization, no other API v1 endpoints consumed in this phase.
- Automatic token refresh via `refresh_token` on 401; if refresh also fails, forces re-login and clears stored tokens.

## Data flow

**Login (once, or on token expiry):**
1. User taps "Iniciar sesión" → in-app browser opens `finance.cd-co.com.py/oauth/authorize`.
2. Logs in with the same credentials as the web app.
3. Redirect to `financespy://oauth/callback` with an authorization code → app exchanges it for tokens (PKCE, no client secret involved).
4. Tokens persisted in Keystore.

**Automatic capture (background, app may be closed):**
1. `NotificationListenerModule` detects a new notification from `com.google.android.apps.walletnfcrel`.
2. Emits raw event to JS: e.g. `{title: "#A EUSTAQUI-PLAZA MADE", text: "PYG112,000 con GNB GOOGLE ••6536"}`.
3. JS regex-extracts `{amount: "112,000", cardText: "GNB GOOGLE ••6536"}`.
4. JS maps `cardText` → `account_id` via the 4-entry table. No match → local notification, abort, nothing sent.
5. POST to `/webhooks/android_purchase` with the Keystore-stored token.
6. Success (`200`/`201`) → local confirmation notification (e.g. "₲112.000 registrado en GNB"). Failure → see Error Handling.

**Viewing recent transactions (manual, app foregrounded):**
1. `GET /api/v1/transactions?per_page=20` with the OAuth `access_token`.
2. Expired token → silent refresh, then retry once.
3. Simple list: date, amount, merchant, account. No interactivity beyond this in the MVP.

## Error handling

- **Notification-listener permission not granted:** persistent in-app banner with a button deep-linking straight to the system settings screen for this permission.
- **Service killed by aggressive OEM battery management:** a known, real risk (this is exactly why the original 2026-07-28 webhook spec routed through Tasker/MacroDroid rather than a bespoke listener in the first place, and why TWA push was ruled out for the same underlying reason — Android's battery management is hostile to background services on some OEMs). Not fully solvable at the app level; mitigate by prompting the user to whitelist the app from battery optimization, with a deep link to that settings screen. Documented as a known limitation, not a bug to "fix."
- **Webhook error responses:**
  - `401`/`503` (token misconfigured) → local notification with the specific error, points at needing to check server config.
  - `422 Unknown account_id` → shouldn't happen given the fixed 4-way mapping, but the same defensive local notification applies if it somehow does.
  - `422 amount...numeric` / timeouts / `5xx` → short backoff retry (a few attempts), then persisted locally as a **pending capture** (date, raw text, attempted account) that the user can review and resend or enter manually from the app later — this is strictly better than Tasker/MacroDroid's fire-and-forget behavior, since a failed capture is never silently lost.
- **Duplicate** (webhook responds `duplicate`, already idempotent server-side) → treated as success in the UI, not surfaced as an error — avoids false-alarm notifications on legitimate retries.
- **OAuth refresh failure** (revoked/expired refresh token) → force re-login, clear stored tokens.

## Testing

- **Regex extraction + card mapping + webhook call logic:** lives entirely in JS/TS (deliberately, so it's testable without a device) — unit tested with Jest, reusing the same confirmed cases already validated server-side (comma-thousands `"112,000"`, dot-thousands `"150.000"`, plain decimals) plus the unmatched-card and duplicate-response paths.
- **Native module:** cannot be meaningfully unit-tested without a live notification. Mitigated by an in-app hidden "Simular notificación" debug action that manually fires the same JS-facing event handler with crafted payloads — lets the full pipeline (extraction → mapping → POST → confirmation) be exercised on-device without waiting for or faking a real purchase. This resurrects the "probar 30 min" idea from the original Gemini report, implemented properly as part of the app rather than a throwaway toggle.
- **No E2E automation** (Detox/Maestro) for this phase — manual QA on Fabrizio's device is sufficient for a single-user personal app.

## Distribution

Signed release APK, installed via `adb install` — same sideload model as `financespy-twa`, no Play Store/TestFlight in this phase. **A new keystore is generated for this app** (do not reuse `financespy-twa`'s `android.keystore` — different app, different package ID, no benefit to sharing). Keystore file and passwords stored in `.local-secrets/`, same convention already used for VM env backups.

## iOS notes (for the future, not built now)

- The notification-capture feature (component 1 above) is Android-only by hard Apple platform restriction, not a scoping choice. As of this writing, Apple's newly-opened `AccessoryNotifications`/`AccessoryLiveActivities` frameworks (2026, EU-only per regulatory mandate) apply to paired hardware accessories (e.g. watches), not to companion phone apps, and do not clearly cover Apple Pay/Wallet-equivalent payment notifications specifically — historically the most protected notification category on iOS. This is expected to remain true for the foreseeable future.
- Components 2 (mapping/webhook logic, minus the native event source) and 3 (auth + transaction list) are plain JS/TS with no Android-specific APIs and should run on iOS with no changes once an iOS build is set up (Xcode, Apple Developer account, signing).
- When iOS is eventually built, the app's value on that platform is login + viewing recent transactions only — Google Wallet purchase capture will need to stay Tasker-equivalent-free but manual entry, or Apple Pay's own on-device parsing if Apple ever exposes something equivalent (unlikely).

## Open items for the implementation plan

- Confirm React Native version and minimum Android SDK target.
- Confirm exact `react-native-app-auth` configuration against Doorkeeper's PKCE requirements (need to verify Doorkeeper's token endpoint response shape matches what the library expects).
- Decide where the RN project lives in the repo (likely a new top-level directory or separate repo — not decided in this spec, revisit at plan time).
- The 4-card mapping table is hardcoded in JS for the MVP; if more cards get added to Wallet later, this requires an app update. Acceptable for personal use; would need to move server-side (fetched at login, e.g. a small new API v1 endpoint) if this ever becomes multi-user.
