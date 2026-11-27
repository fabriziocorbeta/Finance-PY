require "test_helper"

class Investments::MarketTrackerServiceTest < ActiveSupport::TestCase
  setup do
    @mock_provider = mock
    @service = Investments::MarketTrackerService.new(provider: @mock_provider)
  end

  test "valid_range returns valid range or falls back to 1mo" do
    assert_equal "1d", Investments::MarketTrackerService.valid_range("1d")
    assert_equal "5d", Investments::MarketTrackerService.valid_range("5d")
    assert_equal "1y", Investments::MarketTrackerService.valid_range("1y")
    assert_equal "1mo", Investments::MarketTrackerService.valid_range("invalid")
  end

  test "quote_for builds QuoteCard with Series from provider response" do
    quote_series = Provider::YahooFinance::QuoteSeries.new(
      symbol: "^GSPC",
      name: "S&P 500",
      short_name: "S&P 500",
      currency: "USD",
      exchange_name: "SNP",
      instrument_type: "INDEX",
      current_price: 5950.25,
      previous_close: 5900.00,
      change: 50.25,
      change_percent: 0.85,
      day_high: 5960.0,
      day_low: 5910.0,
      fifty_two_week_high: 6050.0,
      fifty_two_week_low: 4800.0,
      volume: 3_500_000_000,
      prices: [
        { date: 2.days.ago.to_date, price: 5880.0 },
        { date: 1.day.ago.to_date, price: 5900.0 },
        { date: Date.current, price: 5950.25 }
      ]
    )

    provider_resp = Provider::Response.new(data: quote_series, error: nil)
    @mock_provider.stubs(:fetch_quote_and_series).returns(provider_resp)

    card = @service.quote_for(ticker: "^GSPC", range: "1mo")

    assert_equal "^GSPC", card.ticker
    assert_equal "S&P 500", card.name
    assert_equal "index", card.category
    assert_equal 5950.25, card.current_price
    assert_equal 0.85, card.change_percent
    assert card.positive?
    assert_not_nil card.series
    assert_equal 3, card.series.values.size
  end

  test "quote_for falls back gracefully when provider fails" do
    @mock_provider.stubs(:fetch_quote_and_series).raises(StandardError, "network timeout")

    card = @service.quote_for(ticker: "VOO", range: "1mo")

    assert_equal "VOO", card.ticker
    assert_equal "equity", card.category
    assert_nil card.current_price
  end

  test "market_overview deduplicates repeated ticker requests across indices and featured quote" do
    quote_series = Provider::YahooFinance::QuoteSeries.new(
      symbol: "^GSPC",
      name: "S&P 500",
      short_name: "S&P 500",
      currency: "USD",
      exchange_name: "SNP",
      instrument_type: "INDEX",
      current_price: 6000.0,
      previous_close: 5950.0,
      change: 50.0,
      change_percent: 0.84,
      day_high: 6010.0,
      day_low: 5940.0,
      fifty_two_week_high: 6100.0,
      fifty_two_week_low: 4900.0,
      volume: 3_000_000_000,
      prices: [
        { date: 1.day.ago.to_date, price: 5950.0 },
        { date: Date.current, price: 6000.0 }
      ]
    )

    provider_resp = Provider::Response.new(data: quote_series, error: nil)
    @mock_provider.expects(:fetch_quote_and_series).times(Investments::MarketTrackerService::DEFAULT_INDICES.size).returns(provider_resp)

    overview = @service.market_overview(
      watchlist_indices: [],
      watchlist_assets: [],
      holdings: [],
      selected_ticker: "^GSPC",
      range: "1mo"
    )

    assert_equal Investments::MarketTrackerService::DEFAULT_INDICES.size, overview[:index_quotes].size
    assert_equal 6000.0, overview[:featured_quote].current_price
  end
end
