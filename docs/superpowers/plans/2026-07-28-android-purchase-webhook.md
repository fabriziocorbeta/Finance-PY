# Android Purchase Notification Webhook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a token-authenticated Rails webhook that a phone-side automation (Tasker/MacroDroid) POSTs to when it detects a Google Play purchase notification, creating a pending (uncategorized) transaction on a real account in FinancePY.

**Architecture:** A new `WebhooksController#android_purchase` action (same controller/pattern as the existing dead `#plaid` actions) authenticates via a bearer token compared with `ActiveSupport::SecurityUtils.secure_compare` (same style already used in `McpController`), then delegates to a new `AndroidPurchase::WebhookProcessor` model that builds a `Transaction`/`Entry` pair using the delegated_type pattern already used everywhere else in this codebase (`Transaction.new(entry: Entry.new(...))`), relying on `Entry`'s existing `(account_id, source, external_id)` uniqueness validation for idempotency — no migration needed.

**Tech Stack:** Ruby on Rails 7.2, Minitest (`ActionDispatch::IntegrationTest` for the controller, plain `ActiveSupport::TestCase` for the processor), existing fixtures (`accounts(:depository)`, `families(:dylan_family)`).

## Global Constraints

- Currency amounts are PYG-style integers in this codebase's convention for this feature — no decimals, matches the format the Android automation is responsible for sending (see spec: `docs/superpowers/specs/2026-07-28-android-purchase-webhook-design.md`).
- No new database migration — reuse the existing `index_entries_on_account_source_and_external_id` unique index (`account_id`, `source`, `external_id`) already present in `db/schema.rb`.
- iOS is explicitly out of scope for this plan.
- Single-family personal-use feature: one shared secret (`ENV["ANDROID_WEBHOOK_TOKEN"]`), no per-family token management.
- Follow the existing `WebhooksController` pattern exactly: `skip_before_action :verify_authenticity_token` and `skip_authentication` are already set at the class level — do not duplicate them per-action.
- Local Ruby is 2.6.6 and cannot run this app's test suite (requires 3.4.7) — per `project_financespy.md` memory, all tests in this plan are written to be run inside the Docker container on the VM (`alejandro-vm`), not locally. Every "Run" command in this plan is prefixed with the Docker invocation used all session: `docker exec financespy-web-1 bin/rails test <path>`. If working directly on the VM's checked-out repo (not via `docker exec` against the running container), adjust accordingly, but do not attempt `bin/rails test` on the local Mac.

---

## Task 1: `AndroidPurchase::WebhookProcessor`

**Files:**
- Create: `app/models/android_purchase/webhook_processor.rb`
- Test: `test/models/android_purchase/webhook_processor_test.rb`

**Interfaces:**
- Consumes: `Account` (existing model, `belongs_to :family`, has `currency` column), `Entry`/`Transaction` (existing delegated_type pair, `Transaction.new(entry: Entry.new(account:, date:, name:, amount:, currency:, source:, external_id:))`).
- Produces: `AndroidPurchase::WebhookProcessor.new(params).process` — `params` is a plain `Hash` (or anything responding to `[:account_id]`/`[:amount]`/`[:merchant]`/`[:item]`/`[:timestamp]`/`[:raw_text]`, e.g. `ActionController::Parameters`). Returns the symbol `:created` on success, `:duplicate` if the same purchase was already recorded. Raises `AndroidPurchase::WebhookProcessor::Error` (a `StandardError` subclass) with a human-readable message if `account_id` is missing or doesn't resolve to a real `Account` — Task 2's controller will catch this and render 422.

- [ ] **Step 1: Write the failing tests**

Create `test/models/android_purchase/webhook_processor_test.rb`:

```ruby
require "test_helper"

class AndroidPurchase::WebhookProcessorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:depository)
  end

  test "creates a negative-amount entry with the merchant/item as the name" do
    result = AndroidPurchase::WebhookProcessor.new(
      account_id: @account.id,
      amount: 50000,
      merchant: "Google Play",
      item: "Some App Pro",
      timestamp: "2026-07-28T10:15:00-04:00",
      raw_text: "Some App Pro - Gs. 50.000"
    ).process

    assert_equal :created, result

    entry = @account.entries.order(created_at: :desc).first
    assert_equal(-50000.0, entry.amount.to_f)
    assert_equal "Google Play - Some App Pro", entry.name
    assert_equal "google_play", entry.source
    assert_equal Date.new(2026, 7, 28), entry.date
    assert_nil entry.transaction.category_id
    assert_equal "Some App Pro - Gs. 50.000", entry.transaction.extra["raw_text"]
  end

  test "forces the amount negative even if a positive number is sent" do
    AndroidPurchase::WebhookProcessor.new(
      account_id: @account.id,
      amount: -50000,
      merchant: "Google Play",
      item: "Some App Pro",
      timestamp: "2026-07-28T10:15:00-04:00",
      raw_text: "x"
    ).process

    entry = @account.entries.order(created_at: :desc).first
    assert_equal(-50000.0, entry.amount.to_f)
  end

  test "is idempotent for the same amount/timestamp/merchant" do
    params = {
      account_id: @account.id,
      amount: 12000,
      merchant: "Google Play",
      item: "Coffee Widget",
      timestamp: "2026-07-28T09:00:00-04:00",
      raw_text: "x"
    }

    first_result = AndroidPurchase::WebhookProcessor.new(params).process
    assert_equal :created, first_result

    assert_no_difference -> { Entry.count } do
      second_result = AndroidPurchase::WebhookProcessor.new(params).process
      assert_equal :duplicate, second_result
    end
  end

  test "raises Error for a missing account_id" do
    error = assert_raises(AndroidPurchase::WebhookProcessor::Error) do
      AndroidPurchase::WebhookProcessor.new(
        account_id: nil,
        amount: 1000,
        merchant: "x",
        item: "x",
        timestamp: "2026-07-28T09:00:00-04:00",
        raw_text: "x"
      ).process
    end
    assert_match(/account_id/, error.message)
  end

  test "raises Error for an unknown account_id" do
    error = assert_raises(AndroidPurchase::WebhookProcessor::Error) do
      AndroidPurchase::WebhookProcessor.new(
        account_id: "00000000-0000-0000-0000-000000000000",
        amount: 1000,
        merchant: "x",
        item: "x",
        timestamp: "2026-07-28T09:00:00-04:00",
        raw_text: "x"
      ).process
    end
    assert_match(/Unknown account_id/, error.message)
  end

  test "falls back to today's date when timestamp is unparseable" do
    AndroidPurchase::WebhookProcessor.new(
      account_id: @account.id,
      amount: 1000,
      merchant: "Google Play",
      item: "x",
      timestamp: "not-a-real-timestamp",
      raw_text: "x"
    ).process

    entry = @account.entries.order(created_at: :desc).first
    assert_equal Date.current, entry.date
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `docker exec financespy-web-1 bin/rails test test/models/android_purchase/webhook_processor_test.rb`
Expected: FAIL — `NameError: uninitialized constant AndroidPurchase::WebhookProcessor` (the class doesn't exist yet).

- [ ] **Step 3: Implement `AndroidPurchase::WebhookProcessor`**

Create `app/models/android_purchase/webhook_processor.rb`:

```ruby
class AndroidPurchase::WebhookProcessor
  Error = Class.new(StandardError)

  def initialize(params)
    @account_id = params[:account_id].to_s
    @amount = params[:amount]
    @merchant = params[:merchant].to_s
    @item = params[:item].to_s
    @timestamp = params[:timestamp].to_s
    @raw_text = params[:raw_text].to_s
  end

  def process
    raise Error, "account_id is required" if @account_id.blank?

    account = Account.find_by(id: @account_id)
    raise Error, "Unknown account_id: #{@account_id}" unless account

    transaction = Transaction.new(
      extra: { "raw_text" => @raw_text, "source" => "google_play", "item" => @item },
      entry: Entry.new(
        account: account,
        date: parsed_date,
        name: description,
        amount: -@amount.to_f.abs,
        currency: account.currency,
        source: "google_play",
        external_id: external_id
      )
    )

    transaction.save!
    :created
  rescue ActiveRecord::RecordInvalid
    raise unless transaction.entry&.errors&.of_kind?(:external_id, :taken)

    :duplicate
  end

  private

    def external_id
      Digest::SHA256.hexdigest("#{@amount}|#{@timestamp}|#{@merchant}")
    end

    def parsed_date
      Time.zone.parse(@timestamp).to_date
    rescue ArgumentError, TypeError
      Date.current
    end

    def description
      [ @merchant, @item ].reject(&:blank?).join(" - ").presence || "Google Play"
    end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `docker exec financespy-web-1 bin/rails test test/models/android_purchase/webhook_processor_test.rb`
Expected: PASS (6 tests, 0 failures)

- [ ] **Step 5: Commit**

```bash
git add app/models/android_purchase/webhook_processor.rb test/models/android_purchase/webhook_processor_test.rb
git commit -m "feat: add AndroidPurchase::WebhookProcessor for phone-notification captures"
```

---

## Task 2: `WebhooksController#android_purchase` + route

**Files:**
- Modify: `app/controllers/webhooks_controller.rb`
- Modify: `config/routes.rb:592-596` (the existing `namespace :webhooks do ... end` block)
- Test: `test/controllers/webhooks_controller_test.rb`

**Interfaces:**
- Consumes: `AndroidPurchase::WebhookProcessor` from Task 1 — `.new(params).process` returning `:created`/`:duplicate`, raising `AndroidPurchase::WebhookProcessor::Error` on bad input.
- Produces: `POST /webhooks/android_purchase` — 200 on success or duplicate, 401 on missing/wrong bearer token, 422 on processor `Error` (bad `account_id`), 400 on any other unexpected exception (mirrors the existing `#plaid` action's catch-all).

- [ ] **Step 1: Write the failing tests**

Replace the contents of `test/controllers/webhooks_controller_test.rb`:

```ruby
require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @account = accounts(:depository)
    @previous_token = ENV["ANDROID_WEBHOOK_TOKEN"]
    ENV["ANDROID_WEBHOOK_TOKEN"] = "test-android-token"
  end

  teardown do
    ENV["ANDROID_WEBHOOK_TOKEN"] = @previous_token
  end

  test "rejects requests with no Authorization header" do
    post webhooks_android_purchase_path, params: valid_payload

    assert_response :unauthorized
  end

  test "rejects requests with the wrong bearer token" do
    post webhooks_android_purchase_path,
      params: valid_payload,
      headers: { "Authorization" => "Bearer wrong-token" }

    assert_response :unauthorized
  end

  test "creates an entry with a valid token and payload" do
    assert_difference -> { Entry.count }, 1 do
      post webhooks_android_purchase_path,
        params: valid_payload,
        headers: { "Authorization" => "Bearer test-android-token" }
    end

    assert_response :success
    assert_equal true, JSON.parse(response.body)["received"]
  end

  test "does not create a second entry for a duplicate payload" do
    post webhooks_android_purchase_path,
      params: valid_payload,
      headers: { "Authorization" => "Bearer test-android-token" }

    assert_no_difference -> { Entry.count } do
      post webhooks_android_purchase_path,
        params: valid_payload,
        headers: { "Authorization" => "Bearer test-android-token" }
    end

    assert_response :success
  end

  test "returns 422 for an unknown account_id" do
    post webhooks_android_purchase_path,
      params: valid_payload.merge(account_id: "00000000-0000-0000-0000-000000000000"),
      headers: { "Authorization" => "Bearer test-android-token" }

    assert_response :unprocessable_entity
  end

  private

    def valid_payload
      {
        account_id: @account.id,
        amount: 50000,
        merchant: "Google Play",
        item: "Some App Pro",
        timestamp: "2026-07-28T10:15:00-04:00",
        raw_text: "Some App Pro - Gs. 50.000"
      }
    end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `docker exec financespy-web-1 bin/rails test test/controllers/webhooks_controller_test.rb`
Expected: FAIL — routing error, `undefined method 'webhooks_android_purchase_path'` (the route doesn't exist yet).

- [ ] **Step 3: Add the route**

In `config/routes.rb`, change the existing block (around line 592):

```ruby
  namespace :webhooks do
    post "plaid"
    post "plaid_eu"
    post "stripe"
    post "android_purchase"
  end
```

- [ ] **Step 4: Run tests again to confirm the routing error is gone and see the real failures**

Run: `docker exec financespy-web-1 bin/rails test test/controllers/webhooks_controller_test.rb`
Expected: FAIL — `AbstractController::ActionNotFound: The action 'android_purchase' could not be found for WebhooksController` (route exists, action doesn't).

- [ ] **Step 5: Implement the controller action**

In `app/controllers/webhooks_controller.rb`, add after the existing `stripe` action, before the final `end`:

```ruby
  def android_purchase
    authenticate_android_webhook!
    return if performed?

    result = AndroidPurchase::WebhookProcessor.new(android_purchase_params).process

    render json: { received: true, duplicate: result == :duplicate }, status: :ok
  rescue AndroidPurchase::WebhookProcessor::Error => error
    Rails.logger.error("Android purchase webhook error: #{error.message}")
    render json: { error: error.message }, status: :unprocessable_entity
  rescue => error
    Sentry.capture_exception(error)
    Rails.logger.error("Android purchase webhook error: #{error.class} - #{error.message}")
    render json: { error: "Invalid webhook" }, status: :bad_request
  end

  private

    def authenticate_android_webhook!
      expected = ENV["ANDROID_WEBHOOK_TOKEN"]

      if expected.blank?
        render json: { error: "Android webhook not configured" }, status: :service_unavailable
        return
      end

      token = request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip

      unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected)
        render json: { error: "unauthorized" }, status: :unauthorized
      end
    end

    def android_purchase_params
      params.permit(:account_id, :amount, :merchant, :item, :timestamp, :raw_text)
    end
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `docker exec financespy-web-1 bin/rails test test/controllers/webhooks_controller_test.rb`
Expected: PASS (5 tests, 0 failures)

- [ ] **Step 7: Run the full processor + controller test files together to check for interference**

Run: `docker exec financespy-web-1 bin/rails test test/models/android_purchase/webhook_processor_test.rb test/controllers/webhooks_controller_test.rb`
Expected: PASS (11 tests, 0 failures)

- [ ] **Step 8: Commit**

```bash
git add app/controllers/webhooks_controller.rb config/routes.rb test/controllers/webhooks_controller_test.rb
git commit -m "feat: add POST /webhooks/android_purchase endpoint"
```

---

## Task 3: Configuration docs + production secret

**Files:**
- Modify: `.env.example`

**Interfaces:**
- Consumes: nothing (documentation only).
- Produces: a documented `ANDROID_WEBHOOK_TOKEN` env var, matching the existing `MCP_API_TOKEN` documentation style in the same file.

- [ ] **Step 1: Document the env var**

In `.env.example`, add after the existing MCP block (the two lines currently reading `# MCP_API_TOKEN=your-random-bearer-token # pipelock:ignore` / `# MCP_USER_EMAIL=user@example.com`):

```
# Optional: Android purchase-notification webhook — enables POST /webhooks/android_purchase
# for phone-side automation (Tasker/MacroDroid) to auto-capture Google Play purchases.
# ANDROID_WEBHOOK_TOKEN=your-random-bearer-token # pipelock:ignore
```

- [ ] **Step 2: Commit**

```bash
git add .env.example
git commit -m "docs: document ANDROID_WEBHOOK_TOKEN env var"
```

- [ ] **Step 3: Generate and set the real secret on the VM (manual, not a code change)**

This step is a deployment action, not a commit — run it once, directly on `alejandro-vm`, after Task 2's commits are deployed:

```bash
# Generate a real secret (run locally, copy the output):
ruby -rsecurerandom -e "puts SecureRandom.hex(32)"

# On the VM, add the generated value to the .env file that compose.prod.yml reads,
# then recreate the web container so it picks up the new env var (same pattern
# used for ONBOARDING_STATE/CORS_ALLOWED_ORIGINS earlier this project — compose.prod.yml
# uses an explicit whitelist, so confirm ANDROID_WEBHOOK_TOKEN is actually passed through
# with: docker compose -f compose.prod.yml exec web env | grep ANDROID_WEBHOOK_TOKEN
# after redeploying, exactly like the CSP_REPORT_ONLY lesson from the 2026-07-18 session).
```

This step is deliberately left as a manual runbook note rather than a scripted task — it touches the production secret file directly and should be confirmed by the human operator, matching the "explicit permission required" handling for changing account/production settings.

---

## Post-implementation manual verification (not automated)

After all 3 tasks are deployed to `alejandro-vm`:

1. `curl -X POST https://finance.cd-co.com.py/webhooks/android_purchase -H "Authorization: Bearer <real-token>" -H "Content-Type: application/json" -d '{"account_id":"<a real account uuid from the production family>","amount":1000,"merchant":"Test","item":"Test item","timestamp":"2026-07-28T12:00:00-04:00","raw_text":"manual curl test"}'` — expect `{"received":true,"duplicate":false}`.
2. Repeat the exact same `curl` call — expect `{"received":true,"duplicate":true}` and confirm no second row appears in the account's transaction list.
3. Set up the actual Tasker/MacroDroid profile on the Android phone per the spec's payload shape, trigger a real (or test) Google Play purchase notification, and confirm the resulting transaction appears in FinancePY's "Sin clasificar" filter with the right amount/date.
