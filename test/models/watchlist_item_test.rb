require "test_helper"

class WatchlistItemTest < ActiveSupport::TestCase
  test "infer_category detects index from caret prefix or quote_type" do
    assert_equal "index", WatchlistItem.infer_category(ticker: "^GSPC")
    assert_equal "index", WatchlistItem.infer_category(ticker: "SPX", quote_type: "INDEX")
  end

  test "infer_category detects etf, crypto, fund, and equity" do
    assert_equal "etf", WatchlistItem.infer_category(ticker: "VOO", quote_type: "ETF")
    assert_equal "crypto", WatchlistItem.infer_category(ticker: "BTC-USD", quote_type: "CRYPTOCURRENCY")
    assert_equal "fund", WatchlistItem.infer_category(ticker: "VFIAX", quote_type: "MUTUALFUND")
    assert_equal "equity", WatchlistItem.infer_category(ticker: "AAPL", quote_type: "EQUITY")
  end

  test "validates uniqueness of security per family and category inclusion" do
    family = families(:dallas)
    security = securities(:aapl)

    first = WatchlistItem.create!(family: family, security: security, category: "equity")
    assert first.persisted?

    duplicate = WatchlistItem.new(family: family, security: security, category: "equity")
    assert_not duplicate.valid?

    invalid_category = WatchlistItem.new(family: family, security: securities(:msft), category: "invalid")
    assert_not invalid_category.valid?
  end
end
