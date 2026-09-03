class AddFamilyIdToPolymorphicIndirectTables < ActiveRecord::Migration[7.2]
  # transactions/valuations/receivables have no direct scoping column: their
  # family is only reachable by joining back to a parent row (Entry/Account)
  # that doesn't exist yet at the moment they're first inserted (Rails saves
  # the delegated_type child before its owner). That join-based RLS policy
  # made every insert fail (see FixPolymorphicIndirectInsertPolicies, which
  # this replaces -- reverted, it introduced a cross-tenant read regression).
  #
  # Denormalizing family_id here matches how every other FORCE RLS table in
  # this schema already works (accounts, budgets, categories, entries: all
  # scoped by a column present on the row itself, not a join to a sibling
  # row). app/models/entry.rb and app/models/account.rb gained a prepended
  # before_save callback that copies family_id onto the entryable/accountable
  # before it's saved, so the column is always populated by the time the
  # INSERT runs -- no join, no ordering dependency, nothing to race.
  # The three UPDATE...FROM backfills below assume each transaction/
  # valuation/receivable has exactly ONE matching entries/accounts row
  # (mirroring Entry's has_one :entryable and Account's has_one
  # :accountable). Nothing at the DB level enforces that uniqueness, so if
  # it were ever violated, Postgres would pick an arbitrary matching row
  # rather than error -- this migration has already run successfully in
  # production against real data with no duplicates, so this is a note for
  # anyone reusing this pattern on a new table, not a live bug here.
  def up
    add_reference :transactions, :family, type: :uuid, foreign_key: true, null: true
    add_reference :valuations, :family, type: :uuid, foreign_key: true, null: true
    add_reference :receivables, :family, type: :uuid, foreign_key: true, null: true

    execute <<~SQL
      UPDATE transactions SET family_id = accounts.family_id
      FROM entries
      JOIN accounts ON accounts.id = entries.account_id
      WHERE entries.entryable_id = transactions.id
        AND entries.entryable_type = 'Transaction';
    SQL

    execute <<~SQL
      UPDATE valuations SET family_id = accounts.family_id
      FROM entries
      JOIN accounts ON accounts.id = entries.account_id
      WHERE entries.entryable_id = valuations.id
        AND entries.entryable_type = 'Valuation';
    SQL

    execute <<~SQL
      UPDATE receivables SET family_id = accounts.family_id
      FROM accounts
      WHERE accounts.accountable_id = receivables.id
        AND accounts.accountable_type = 'Receivable';
    SQL

    change_column_null :transactions, :family_id, false
    change_column_null :valuations, :family_id, false
    change_column_null :receivables, :family_id, false
  end

  def down
    remove_reference :transactions, :family, foreign_key: true
    remove_reference :valuations, :family, foreign_key: true
    remove_reference :receivables, :family, foreign_key: true
  end
end
