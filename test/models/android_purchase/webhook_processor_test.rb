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
