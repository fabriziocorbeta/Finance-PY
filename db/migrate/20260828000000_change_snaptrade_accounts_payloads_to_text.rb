class ChangeSnaptradeAccountsPayloadsToText < ActiveRecord::Migration[7.2]
  def change
    change_column :snaptrade_accounts, :raw_payload, :text, default: nil
    change_column :snaptrade_accounts, :raw_transactions_payload, :text, default: nil
    change_column :snaptrade_accounts, :raw_holdings_payload, :text, default: "[]"
    change_column :snaptrade_accounts, :raw_activities_payload, :text, default: "[]"
  end
end
