class AddMissingIndexForAccountProvidersRls < ActiveRecord::Migration[7.2]
  # account_providers has no index on account_id today (verified against
  # db/structure.sql: only a primary key + no other indexes). Its RLS
  # policy (added in a later migration this same batch) is evaluated on
  # every row via `account_id IN (SELECT id FROM accounts WHERE family_id =
  # current_family_id())`, so an unindexed account_id forces a seq scan on
  # every read of this table once the policy is live.
  disable_ddl_transaction!

  def change
    add_index :account_providers, :account_id, algorithm: :concurrently, if_not_exists: true
  end
end
