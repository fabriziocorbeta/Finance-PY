require "test_helper"

# Tests SentryPiiScrubber (config/initializers/sentry.rb) as a pure function,
# independent of a real Sentry DSN/connection. This module backs the
# before_send / before_breadcrumb callbacks wired up in Sentry.init, which
# only run when SENTRY_DSN is present -- so we exercise the scrubbing logic
# directly here instead of requiring real Sentry credentials.
class SentryPiiScrubberTest < ActiveSupport::TestCase
  test "filters sensitive financial fields from a hash" do
    input = {
      amount: 1234.56,
      notes: "private note about the client",
      client_name: "Acme Corp",
      balance: 99999.99,
      merchant: "Some Merchant",
      address: "123 Main St",
      phone: "+595981234567",
      email: "user@example.com",
      status: "posted"
    }

    result = SentryPiiScrubber.scrub(input)

    assert_equal "[FILTERED]", result[:amount]
    assert_equal "[FILTERED]", result[:notes]
    assert_equal "[FILTERED]", result[:client_name]
    assert_equal "[FILTERED]", result[:balance]
    assert_equal "[FILTERED]", result[:merchant]
    assert_equal "[FILTERED]", result[:address]
    assert_equal "[FILTERED]", result[:phone]
    assert_equal "[FILTERED]", result[:email]
    # Non-sensitive fields pass through untouched
    assert_equal "posted", result[:status]
  end

  test "filters nested hashes" do
    input = {
      entry: {
        amount: 500,
        notes: "secret",
        entryable_attributes: { merchant: "Acme" }
      }
    }

    result = SentryPiiScrubber.scrub(input)

    assert_equal "[FILTERED]", result[:entry][:amount]
    assert_equal "[FILTERED]", result[:entry][:notes]
    assert_equal "[FILTERED]", result[:entry][:entryable_attributes][:merchant]
  end

  test "filters fields inside a JSON-encoded request body string" do
    json_body = { amount: 42, notes: "sensitive", status: "ok" }.to_json

    result = SentryPiiScrubber.scrub(json_body)
    parsed = JSON.parse(result)

    assert_equal "[FILTERED]", parsed["amount"]
    assert_equal "[FILTERED]", parsed["notes"]
    assert_equal "ok", parsed["status"]
  end

  test "leaves a non-JSON string untouched" do
    assert_equal "just some text", SentryPiiScrubber.scrub("just some text")
  end

  test "leaves nil and other scalar values untouched" do
    assert_nil SentryPiiScrubber.scrub(nil)
    assert_equal 42, SentryPiiScrubber.scrub(42)
    assert_equal true, SentryPiiScrubber.scrub(true)
  end

  test "before_send callback scrubs request data on a simulated Sentry event" do
    fake_request = Struct.new(:data).new({ amount: 777, notes: "top secret", ok: "field" })
    fake_event = Struct.new(:request).new(fake_request)

    before_send = lambda do |event, _hint|
      if event.respond_to?(:request) && event.request&.data
        event.request.data = SentryPiiScrubber.scrub(event.request.data)
      end
      event
    end

    result = before_send.call(fake_event, {})

    assert_equal "[FILTERED]", result.request.data[:amount]
    assert_equal "[FILTERED]", result.request.data[:notes]
    assert_equal "field", result.request.data[:ok]
  end

  test "before_breadcrumb callback scrubs breadcrumb data" do
    fake_breadcrumb = Struct.new(:data).new({ amount: 123, notes: "leak me", safe: "value" })

    before_breadcrumb = lambda do |breadcrumb, _hint|
      breadcrumb.data = SentryPiiScrubber.scrub(breadcrumb.data) if breadcrumb.data
      breadcrumb
    end

    result = before_breadcrumb.call(fake_breadcrumb, {})

    assert_equal "[FILTERED]", result.data[:amount]
    assert_equal "[FILTERED]", result.data[:notes]
    assert_equal "value", result.data[:safe]
  end
end
