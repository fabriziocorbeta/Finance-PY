# frozen_string_literal: true

require "test_helper"

class Api::V1::ExchangeRatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)

    @user.api_keys.active.destroy_all

    @auth = ApiKey.create!(
      user: @user,
      name: "Test Read Key",
      scopes: [ "read" ],
      display_key: "test_ro_#{SecureRandom.hex(8)}",
      source: "mobile"
    )

    Redis.new.del("api_rate_limit:#{@auth.id}")
  end

  test "should require authentication" do
    get "/api/v1/exchange_rate", params: { from: "USD", to: "EUR" }
    assert_response :unauthorized
  end

  test "read-only API key can access exchange_rate" do
    ExchangeRate.create!(from_currency: "EUR", to_currency: "USD", date: Date.current, rate: 1.2)

    get "/api/v1/exchange_rate", params: { from: "EUR", to: "USD" }, headers: api_headers(@auth)

    assert_response :success
  end

  test "returns rate for different currencies" do
    ExchangeRate.create!(from_currency: "EUR", to_currency: "USD", date: Date.current, rate: 1.2)

    get "/api/v1/exchange_rate", params: { from: "EUR", to: "USD", date: Date.current }, headers: api_headers(@auth)

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "1.2", json_response["rate"]
  end

  test "returns same_currency flag for matching currencies" do
    get "/api/v1/exchange_rate", params: { from: "USD", to: "USD" }, headers: api_headers(@auth)

    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response["same_currency"]
    assert_equal "1.0", json_response["rate"]
  end

  test "uses provided date for rate lookup" do
    custom_date = 3.days.ago.to_date
    ExchangeRate.create!(from_currency: "EUR", to_currency: "USD", date: custom_date, rate: 1.25)

    get "/api/v1/exchange_rate", params: { from: "EUR", to: "USD", date: custom_date }, headers: api_headers(@auth)

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "1.25", json_response["rate"]
  end

  test "defaults to current date when not provided" do
    ExchangeRate.create!(from_currency: "EUR", to_currency: "USD", date: Date.current, rate: 1.2)

    get "/api/v1/exchange_rate", params: { from: "EUR", to: "USD" }, headers: api_headers(@auth)

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "1.2", json_response["rate"]
  end

  test "returns 400 when from currency is missing" do
    get "/api/v1/exchange_rate", params: { to: "USD" }, headers: api_headers(@auth)

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "from and to currencies are required", json_response["message"]
  end

  test "returns 400 when to currency is missing" do
    get "/api/v1/exchange_rate", params: { from: "EUR" }, headers: api_headers(@auth)

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "from and to currencies are required", json_response["message"]
  end

  test "returns 400 on invalid date format" do
    get "/api/v1/exchange_rate", params: { from: "EUR", to: "USD", date: "not-a-date" }, headers: api_headers(@auth)

    assert_response :bad_request
    json_response = JSON.parse(response.body)
    assert_equal "Invalid date format", json_response["message"]
  end

  test "returns 404 when rate not found" do
    get "/api/v1/exchange_rate", params: { from: "EUR", to: "USD", date: Date.current }, headers: api_headers(@auth)

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "Exchange rate not found", json_response["message"]
    assert json_response["rate_hint"].present?
  end

  test "handles uppercase and lowercase currency codes" do
    ExchangeRate.create!(from_currency: "EUR", to_currency: "USD", date: Date.current, rate: 1.2)

    get "/api/v1/exchange_rate", params: { from: "eur", to: "usd" }, headers: api_headers(@auth)

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "1.2", json_response["rate"]
  end

  test "returns the precise rate as a string even when object has rate method" do
    rate_obj = OpenStruct.new(rate: 1.2)

    ExchangeRate.expects(:find_or_fetch_rate)
                .with(from: "EUR", to: "USD", date: Date.current)
                .returns(rate_obj)

    get "/api/v1/exchange_rate", params: { from: "EUR", to: "USD" }, headers: api_headers(@auth)

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "1.2", json_response["rate"]
    assert_instance_of String, json_response["rate"]
  end

  test "returns a high-precision rate without losing significant digits" do
    rate_obj = OpenStruct.new(rate: BigDecimal("0.0001572730861279"))

    ExchangeRate.expects(:find_or_fetch_rate)
                .with(from: "USD", to: "PYG", date: Date.current)
                .returns(rate_obj)

    get "/api/v1/exchange_rate", params: { from: "USD", to: "PYG" }, headers: api_headers(@auth)

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal "0.0001572730861279", json_response["rate"]
  end

  test "flags a carried-forward rate as stale and surfaces its real date" do
    older_date = 2.days.ago.to_date
    rate_obj = ExchangeRate.new(from_currency: "EUR", to_currency: "USD", date: older_date, rate: 1.2)

    ExchangeRate.expects(:find_or_fetch_rate)
                .with(from: "EUR", to: "USD", date: Date.current)
                .returns(rate_obj)

    get "/api/v1/exchange_rate", params: { from: "EUR", to: "USD" }, headers: api_headers(@auth)

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal older_date.to_s, json_response["rate_date"]
    assert json_response["stale"]
    assert json_response["rate_hint"].present?
  end

  test "does not flag a same-date rate as stale" do
    rate_obj = ExchangeRate.new(from_currency: "EUR", to_currency: "USD", date: Date.current, rate: 1.2)

    ExchangeRate.expects(:find_or_fetch_rate)
                .with(from: "EUR", to: "USD", date: Date.current)
                .returns(rate_obj)

    get "/api/v1/exchange_rate", params: { from: "EUR", to: "USD" }, headers: api_headers(@auth)

    assert_response :success
    json_response = JSON.parse(response.body)
    assert_equal Date.current.to_s, json_response["rate_date"]
    assert_not json_response["stale"]
  end

  test "returns error when find_or_fetch_rate raises exception" do
    ExchangeRate.expects(:find_or_fetch_rate)
                .with(from: "EUR", to: "USD", date: Date.current)
                .raises(StandardError, "Rate fetch failed")

    get "/api/v1/exchange_rate", params: { from: "EUR", to: "USD" }, headers: api_headers(@auth)

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "Failed to fetch exchange rate", json_response["message"]
  end

  private

    def api_headers(auth)
      { "X-Api-Key" => auth.display_key }
    end
end
