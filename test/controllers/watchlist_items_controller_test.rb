require "test_helper"

class WatchlistItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    sign_in @user
  end

  test "creates watchlist item from ticker" do
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
      period_change: nil,
      period_change_percent: nil,
      day_high: nil,
      day_low: nil,
      fifty_two_week_high: nil,
      fifty_two_week_low: nil,
      volume: nil,
      series: nil,
      security: nil,
      watchlist_item: nil
    )

    Investments::MarketTrackerService.any_instance.stubs(:quote_for).returns(stub_card)

    assert_difference -> { @user.family.watchlist_items.count }, 1 do
      post watchlist_items_path, params: { ticker: "VOO" }
    end

    assert_redirected_to investments_path(ticker: "VOO")
    item = @user.family.watchlist_items.order(:created_at).last
    assert_equal "etf", item.category
    assert_equal "VOO", item.ticker
  end

  test "destroys watchlist item" do
    security = securities(:aapl)
    item = WatchlistItem.create!(family: @user.family, security: security, category: "equity")

    assert_difference -> { @user.family.watchlist_items.count }, -1 do
      delete watchlist_item_path(item)
    end

    assert_redirected_to investments_path
  end
end
