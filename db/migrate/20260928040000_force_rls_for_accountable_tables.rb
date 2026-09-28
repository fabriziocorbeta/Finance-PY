class ForceRlsForAccountableTables < ActiveRecord::Migration[7.2]
  TABLES = %i[
    depositories
    investments
    cryptos
    properties
    vehicles
    other_assets
    credit_cards
    loans
    other_liabilities
    trades
    account_shares
    account_providers
  ].freeze

  def up
    TABLES.each do |table|
      execute "ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;"
    end
  end

  def down
    TABLES.each do |table|
      execute "ALTER TABLE #{table} NO FORCE ROW LEVEL SECURITY;"
    end
  end
end
