# Android Purchase Notification Webhook — Design Spec

**Date:** 2026-07-28
**Project:** FinancePY (repo `cd-co-erp`, branch `main`)
**Status:** Approved, ready for implementation plan

## Purpose

Auto-capture Google Play purchase notifications from an Android phone into FinancePY as pending transactions, without opening the app. A phone-side automation tool (Tasker or MacroDroid) reads the purchase notification via Android's `NotificationListenerService`, extracts amount/merchant/item with its own regex, and POSTs the result to a new Rails webhook endpoint.

This is a personal-use feature (single user, single phone, single shared secret) — not a multi-tenant product feature. iOS is explicitly out of scope (no reliable notification-reading API pre-iOS 27).

## Non-goals

- No iOS support in this phase.
- No email-receipt parsing fallback (deferred; only in-scope if the notification-based path proves unreliable).
- No new UI. Captured transactions surface via the existing "Sin clasificar" (uncategorized) filter already in the transactions list.
- No HMAC signing — a bearer token is sufficient for a single-user secret.

## Architecture

Follows the existing `WebhooksController` pattern (same shape as the dead `#plaid`/`#plaid_eu` actions already in the codebase):

```
Tasker/MacroDroid (Android)
  --POST--> WebhooksController#android_purchase
              -> AndroidPurchase::WebhookProcessor.new(params).process
                   -> builds Entry + Transaction, honoring the existing
                      (account_id, source, external_id) unique index
```

### Route

```ruby
namespace :webhooks do
  post "android_purchase"
end
```

### Controller

`app/controllers/webhooks_controller.rb`, new action `#android_purchase`:
- `skip_before_action :verify_authenticity_token` (already applied at class level)
- `skip_authentication` (already applied at class level)
- Bearer token check via `authenticate_or_request_with_http_token` + `ActiveSupport::SecurityUtils.secure_compare` against `ENV["ANDROID_WEBHOOK_TOKEN"]`. 401 on mismatch.
- Delegates to `AndroidPurchase::WebhookProcessor`, catches its errors the same way `#plaid` does (`Sentry.capture_exception`, log, render `400`).

### Expected payload

```json
{
  "amount": 50000,
  "merchant": "Google Play",
  "item": "Some App Pro subscription",
  "timestamp": "2026-07-28T10:15:00-04:00",
  "account_id": "<uuid of the real account these should land in>",
  "raw_text": "the full original notification text, for debugging/audit"
}
```

`account_id` is fixed per Tasker/MacroDroid configuration (the user picks the real card/account once when setting up the automation — confirmed in brainstorming: captured purchases attach to an existing real account, e.g. the same AMEX Gold already used for statement imports, not a dedicated synthetic account).

`amount` arrives as a plain integer in PYG (no decimals) — Tasker's own regex is responsible for stripping any "Gs." / "$" / thousands-separator formatting on the phone side before sending. The webhook does not attempt currency-format inference (unlike the PDF importer, which has to guess from ambiguous statement text — here the automation controls the format it sends).

### Processor: `app/models/android_purchase/webhook_processor.rb`

Responsibilities:
1. Look up the `Account` by `account_id`, scoped to the family that owns `ANDROID_WEBHOOK_TOKEN` (single-family feature — the token implies the family, there is exactly one family this runs for).
2. Compute an idempotency key: `Digest::SHA256.hexdigest("#{amount}|#{timestamp}|#{merchant}")`, stored as `Entry#external_id` with `Entry#source = "google_play"`. This reuses the existing unique index `index_entries_on_account_source_and_external_id` — no migration needed. A retried/duplicate POST (e.g. Tasker retry after a network blip) raises `ActiveRecord::RecordNotUnique`, which the controller treats as an idempotent no-op (200, not an error) rather than a failure.
3. Create `Entry` + nested `Transaction` (delegated type), `category: nil` (surfaces in the existing "Sin clasificar" filter), amount sign: Google Play purchases are always a debit, so amount is stored as negative regardless of the sign Tasker sends (defensive — force `-amount.abs`).
4. `Transaction#extra` (existing jsonb column) stores `{"raw_text" => ..., "source" => "google_play", "item" => ...}` for audit/debugging if the parse ever looks wrong.

### Error handling

- Missing/invalid token → 401, no processing attempted, no Sentry noise (this is expected background noise from scanners hitting the endpoint, not an error).
- Missing `account_id`, or `account_id` not found / not owned by the configured family → 422, logged, Sentry (this indicates a phone-side config bug, worth knowing about).
- Duplicate (unique constraint) → 200, logged at `info` (not `error`) — this is the idempotency path working as intended, not a failure.
- Any other exception → 400, `Sentry.capture_exception`, same as the existing `#plaid` pattern.

### Testing

- Controller test: valid token + valid payload creates one `Entry`/`Transaction`; invalid token → 401 and no record created; duplicate payload (same amount/timestamp/merchant) → 200 and no second record created; missing `account_id` → 422.
- No system/browser test needed (no UI surface).

## Open items deferred (explicitly out of scope for this pass)

- Rate limiting the endpoint (rack-attack) — worth adding if this endpoint is ever probed/abused, not needed for a single-user secret at low volume, but noted so it isn't forgotten if traffic ever looks off in logs.
- Email-receipt fallback for cases where the Android automation misses a notification (battery optimization killing Tasker, etc.) — revisit only if drift between what's captured and reality becomes a real annoyance in practice.
