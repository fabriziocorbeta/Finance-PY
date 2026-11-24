require "test_helper"

class InvestmentsControllerTest < ActionDispatch::IntegrationTest
  include AccountableResourceInterfaceTest

  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:investment)
  end

  test "gets investments index with market indices and portfolio" do
    stub_card = Investments::MarketTrackerService::QuoteCard.new(
      ticker: "^GSPC",
      name: "S&P 500",
      category: "index",
      currency: "USD",
      exchange_name: "SNP",
      current_price: 5950.0,
      previous_close: 5900.0,
      change: 50.0,
      change_percent: 0.85,
      period_change: 120.0,
      period_change_percent: 2.06,
      day_high: 5960.0,
      day_low: 5910.0,
      fifty_two_week_high: 6050.0,
      fifty_two_week_low: 4800.0,
      volume: 1_000_000,
      series: nil,
      security: nil,
      watchlist_item: nil
    )

    Investments::MarketTrackerService.any_instance.stubs(:index_quotes).returns([ stub_card ])
    Investments::MarketTrackerService.any_instance.stubs(:watchlist_quotes).returns([])
    Investments::MarketTrackerService.any_instance.stubs(:holding_quotes).returns({})
    Investments::MarketTrackerService.any_instance.stubs(:quote_for).returns(stub_card)

    get investments_path
    assert_response :success
    assert_select "h1", text: /Inversiones|Investments/
  end

  test "gets quote turbo frame partial" do
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
      period_change: 15.0,
      period_change_percent: 2.86,
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

    get quote_investments_path(ticker: "VOO", range: "3mo")
    assert_response :success
    assert_match "Vanguard S&P 500 ETF", response.body
  end
end
