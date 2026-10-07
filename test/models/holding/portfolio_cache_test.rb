require "test_helper"

class Holding::PortfolioCacheTest < ActiveSupport::TestCase
  include EntriesTestHelper, ProviderTestHelper

  setup do
    @provider = mock
    Security.stubs(:provider).returns(@provider)

    @account = families(:empty).accounts.create!(
      name: "Test Brokerage",
      balance: 10000,
      currency: "USD",
      accountable: Investment.new
    )

    @security = Security.create!(name: "Test Security", ticker: "TEST", exchange_operating_mic: "TEST")

    @trade = create_trade(@security, account: @account, qty: 1, date: 2.days.ago.to_date, price: 210.23).trade
  end

  test "gets price from DB if available" do
    db_price = 210

    Security::Price.create!(
      security: @security,
      date: Date.current,
      price: db_price
    )

    cache = Holding::PortfolioCache.new(@account)
    assert_equal db_price, cache.get_price(@security.id, Date.current).price
  end

  test "if no price from db, try getting the price from trades" do
    Security::Price.destroy_all

    cache = Holding::PortfolioCache.new(@account)
    assert_equal @trade.price, cache.get_price(@security.id, @trade.entry.date).price
  end

  test "if no price from db or trades, search holdings" do
    Security::Price.delete_all
    Entry.delete_all

    holding = Holding.create!(
      security: @security,
      account: @account,
      date: Date.current,
      qty: 1,
      price: 250,
      amount: 250 * 1,
      currency: "USD"
    )

    cache = Holding::PortfolioCache.new(@account, use_holdings: true)
    assert_equal holding.price, cache.get_price(@security.id, holding.date).price
  end

  # Regression test for a real production incident: a Trade row deleted
  # independently of its parent Entry (entryable is a polymorphic (type, id)
  # pair, not a real foreign key, so the DB doesn't stop this) left an Entry
  # with entryable_type "Trade" pointing at nothing. #trades previously did
  # `trade_entry.entryable.security_id` with no nil check, so every sync for
  # the account crashed with `undefined method 'security_id' for nil` from
  # then on -- the account's balance (and its holdings/"detail" view) never
  # updated again.
  test "skips an entry whose Trade row no longer exists instead of crashing" do
    orphaned_entry = @trade.entry
    Trade.delete(@trade.id) # bypasses callbacks/dependent destroy on purpose, like the prod anomaly

    cache = nil
    assert_nothing_raised do
      cache = Holding::PortfolioCache.new(@account)
    end

    assert_equal [], cache.get_trades(date: orphaned_entry.date)
    assert_equal [], cache.get_trades
  end
end
