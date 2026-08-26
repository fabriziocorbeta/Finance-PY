require "test_helper"

class AndroidPurchase::WebhookProcessorTest < ActiveSupport::TestCase
  setup do
    @account = accounts(:depository)
  end

  test "creates a positive-amount entry with the merchant/item as the name" do
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
    assert_equal(50000.0, entry.amount.to_f)
    assert_equal "Google Play - Some App Pro", entry.name
    assert_equal "google_play", entry.source
    assert_equal Date.new(2026, 7, 28), entry.date
    assert_nil entry.transaction.category_id
    assert_equal "Some App Pro - Gs. 50.000", entry.transaction.extra["raw_text"]
  end

  test "forces the amount positive even if a negative number is sent" do
    AndroidPurchase::WebhookProcessor.new(
      account_id: @account.id,
      amount: -50000,
      merchant: "Google Play",
      item: "Some App Pro",
      timestamp: "2026-07-28T10:15:00-04:00",
      raw_text: "x"
    ).process

    entry = @account.entries.order(created_at: :desc).first
    assert_equal(50000.0, entry.amount.to_f)
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

  test "raises Error for a missing amount instead of silently creating a zero-amount entry" do
    error = assert_raises(AndroidPurchase::WebhookProcessor::Error) do
      AndroidPurchase::WebhookProcessor.new(
        account_id: @account.id,
        amount: nil,
        merchant: "x",
        item: "x",
        timestamp: "2026-07-28T09:00:00-04:00",
        raw_text: "x"
      ).process
    end
    assert_match(/amount/, error.message)
  end

  test "raises Error for a non-numeric amount" do
    error = assert_raises(AndroidPurchase::WebhookProcessor::Error) do
      AndroidPurchase::WebhookProcessor.new(
        account_id: @account.id,
        amount: "not-a-number",
        merchant: "x",
        item: "x",
        timestamp: "2026-07-28T09:00:00-04:00",
        raw_text: "x"
      ).process
    end
    assert_match(/amount/, error.message)
  end

  test "treats a real Google Wallet PYG comma-thousands amount as whole guaranies, not a 1000x-smaller decimal" do
    # Confirmed against a real notification: "PYG112,000 con GNB GOOGLE ••6536"
    result = AndroidPurchase::WebhookProcessor.new(
      account_id: @account.id,
      amount: "112,000",
      merchant: "Google Play",
      item: "Real Wallet notification format",
      timestamp: "2026-07-28T09:00:00-04:00",
      raw_text: "PYG112,000 con GNB GOOGLE ••6536"
    ).process

    assert_equal :created, result
    entry = @account.entries.order(created_at: :desc).first
    assert_equal(112000.0, entry.amount.to_f)
  end

  test "treats a multi-group comma-thousands amount correctly" do
    result = AndroidPurchase::WebhookProcessor.new(
      account_id: @account.id,
      amount: "1,250,000",
      merchant: "Google Play",
      item: "Large comma-thousands amount",
      timestamp: "2026-07-28T09:00:00-04:00",
      raw_text: "x"
    ).process

    assert_equal :created, result
    entry = @account.entries.order(created_at: :desc).first
    assert_equal(1250000.0, entry.amount.to_f)
  end

  test "treats an unconfirmed dot-thousands string amount as whole guaranies, not a 1000x-smaller decimal" do
    result = AndroidPurchase::WebhookProcessor.new(
      account_id: @account.id,
      amount: "150.000",
      merchant: "Google Play",
      item: "PYG thousands format",
      timestamp: "2026-07-28T09:00:00-04:00",
      raw_text: "x"
    ).process

    assert_equal :created, result
    entry = @account.entries.order(created_at: :desc).first
    assert_equal(150000.0, entry.amount.to_f)
  end

  test "treats a multi-group dot-thousands string amount correctly" do
    result = AndroidPurchase::WebhookProcessor.new(
      account_id: @account.id,
      amount: "1.250.000",
      merchant: "Google Play",
      item: "Large PYG amount",
      timestamp: "2026-07-28T09:00:00-04:00",
      raw_text: "x"
    ).process

    assert_equal :created, result
    entry = @account.entries.order(created_at: :desc).first
    assert_equal(1250000.0, entry.amount.to_f)
  end

  test "still treats a plain decimal string amount as a decimal, not thousands-separated" do
    result = AndroidPurchase::WebhookProcessor.new(
      account_id: @account.id,
      amount: "12.50",
      merchant: "Google Play",
      item: "USD-style decimal",
      timestamp: "2026-07-28T09:00:00-04:00",
      raw_text: "x"
    ).process

    assert_equal :created, result
    entry = @account.entries.order(created_at: :desc).first
    assert_equal(12.5, entry.amount.to_f)
  end

  test "treats a comma-decimal string amount (LatAm format) correctly" do
    result = AndroidPurchase::WebhookProcessor.new(
      account_id: @account.id,
      amount: "1.250.000,50",
      merchant: "Google Play",
      item: "Comma decimal format",
      timestamp: "2026-07-28T09:00:00-04:00",
      raw_text: "x"
    ).process

    assert_equal :created, result
    entry = @account.entries.order(created_at: :desc).first
    assert_equal(1250000.50, entry.amount.to_f)
  end

  test "accepts a numeric amount sent as a string" do
    result = AndroidPurchase::WebhookProcessor.new(
      account_id: @account.id,
      amount: "7500",
      merchant: "Google Play",
      item: "String amount",
      timestamp: "2026-07-28T09:00:00-04:00",
      raw_text: "x"
    ).process

    assert_equal :created, result
    entry = @account.entries.order(created_at: :desc).first
    assert_equal(7500.0, entry.amount.to_f)
  end

  test "treats a duplicate that hits the DB unique index (not just the app-level validation) as idempotent" do
    params = {
      account_id: @account.id,
      amount: 33000,
      merchant: "Google Play",
      item: "Race condition test",
      timestamp: "2026-07-28T09:30:00-04:00",
      raw_text: "x"
    }

    AndroidPurchase::WebhookProcessor.new(params).process

    # Simulate two near-simultaneous requests: the app-level uniqueness
    # validation only sees committed rows, so stub it to report "not taken"
    # (as it would for a request racing just ahead of the first one's
    # commit), forcing the actual insert to hit the DB's unique index and
    # raise ActiveRecord::RecordNotUnique instead of ActiveRecord::RecordInvalid.
    Entry.any_instance.stubs(:valid?).returns(true)

    assert_no_difference -> { Entry.count } do
      result = AndroidPurchase::WebhookProcessor.new(params).process
      assert_equal :duplicate, result
    end
  end

  test "does not require ANDROID_WEBHOOK_FAMILY_ID and allows any account when unset" do
    assert_nil ENV["ANDROID_WEBHOOK_FAMILY_ID"]

    result = AndroidPurchase::WebhookProcessor.new(
      account_id: @account.id,
      amount: 1000,
      merchant: "Google Play",
      item: "x",
      timestamp: "2026-07-28T09:00:00-04:00",
      raw_text: "x"
    ).process

    assert_equal :created, result
  end

  test "rejects an account_id belonging to a different family than ANDROID_WEBHOOK_FAMILY_ID, with the same message as an unknown account" do
    other_family = families(:inactive_trial)
    other_account = Account.create!(
      family: other_family, name: "Other Family Account", balance: 0, currency: "USD",
      accountable: Depository.new
    )

    previous = ENV["ANDROID_WEBHOOK_FAMILY_ID"]
    ENV["ANDROID_WEBHOOK_FAMILY_ID"] = @account.family_id

    error = assert_raises(AndroidPurchase::WebhookProcessor::Error) do
      AndroidPurchase::WebhookProcessor.new(
        account_id: other_account.id,
        amount: 1000,
        merchant: "x",
        item: "x",
        timestamp: "2026-07-28T09:00:00-04:00",
        raw_text: "x"
      ).process
    end
    assert_match(/Unknown account_id/, error.message)
  ensure
    ENV["ANDROID_WEBHOOK_FAMILY_ID"] = previous
  end

  test "allows an account_id in the configured family when ANDROID_WEBHOOK_FAMILY_ID is set" do
    previous = ENV["ANDROID_WEBHOOK_FAMILY_ID"]
    ENV["ANDROID_WEBHOOK_FAMILY_ID"] = @account.family_id

    result = AndroidPurchase::WebhookProcessor.new(
      account_id: @account.id,
      amount: 1000,
      merchant: "Google Play",
      item: "x",
      timestamp: "2026-07-28T09:00:00-04:00",
      raw_text: "x"
    ).process

    assert_equal :created, result
  ensure
    ENV["ANDROID_WEBHOOK_FAMILY_ID"] = previous
  end
end
