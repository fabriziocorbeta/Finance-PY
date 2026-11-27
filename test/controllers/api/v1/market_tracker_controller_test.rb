# frozen_string_literal: true

require "test_helper"

class Api::V1::MarketTrackerControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.api_keys.active.destroy_all

    @api_key = ApiKey.create!(
      user: @user,
      name: "Test Read Key",
      scopes: [ "read" ],
      source: "web",
      display_key: "test_read_#{SecureRandom.hex(8)}"
    )
  end

  test "returns market tracker payload with index quotes and featured quote" do
    stub_card = Investments::MarketTrackerService::QuoteCard.new(
      ticker: "^GSPC",
      name: "S&P 500",
      category: "index",
      currency: "USD",
      exchange_name: "SNP",
      current_price: 7237.17,
      previous_close: 7623.0,
      change: -385.83,
      change_percent: -5.07,
      period_change: -100.0,
      period_change_percent: -1.36,
      day_high: 7300.0,
      day_low: 7200.0,
      fifty_two_week_high: 7500.0,
      fifty_two_week_low: 5800.0,
      volume: 3_000_000,
      series: nil,
      security: nil,
      watchlist_item: nil
    )

    Investments::MarketTrackerService.any_instance.stubs(:market_overview).returns(
      index_quotes: [ stub_card ],
      watchlist_quotes: [],
      holding_quotes: {},
      featured_quote: stub_card
    )

    get api_v1_market_tracker_url, headers: api_headers(@api_key)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "^GSPC", body["index_quotes"].first["ticker"]
    assert_equal 7237.17, body["featured_quote"]["current_price"]
  end

  test "returns quote for ticker and range" do
    stub_card = Investments::MarketTrackerService::QuoteCard.new(
      ticker: "VOO",
      name: "Vanguard S&P 500 ETF",
      category: "etf",
      currency: "USD",
      exchange_name: "PCX",
      current_price: 540.0,
      previous_close: 535.0,
      change: 5.0,
      change_percent: 0.93,
      period_change: 12.0,
      period_change_percent: 2.27,
      day_high: 542.0,
      day_low: 536.0,
      fifty_two_week_high: 550.0,
      fifty_two_week_low: 440.0,
      volume: 500_000,
      series: nil,
      security: nil,
      watchlist_item: nil
    )

    Investments::MarketTrackerService.any_instance.stubs(:quote_for).returns(stub_card)

    get quote_api_v1_market_tracker_url(ticker: "VOO", range: "3mo"), headers: api_headers(@api_key)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "VOO", body["quote"]["ticker"]
    assert_equal "etf", body["quote"]["category"]
  end

  test "requires authentication" do
    get api_v1_market_tracker_url

    assert_response :unauthorized
  end
end
