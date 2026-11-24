# frozen_string_literal: true

require "test_helper"

class Api::V1::WatchlistItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @user.api_keys.active.destroy_all

    @api_key = ApiKey.create!(
      user: @user,
      name: "Test Write Key",
      scopes: [ "read_write" ],
      source: "web",
      display_key: "test_write_#{SecureRandom.hex(8)}"
    )
  end

  test "creates and destroys watchlist item" do
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
      post api_v1_watchlist_items_url,
           params: { ticker: "VOO" },
           headers: api_headers(@api_key),
           as: :json
    end

    assert_response :created
    created_id = JSON.parse(response.body).dig("watchlist_item", "id")

    assert_difference -> { @user.family.watchlist_items.count }, -1 do
      delete api_v1_watchlist_item_url(created_id), headers: api_headers(@api_key)
    end

    assert_response :ok
  end
end
