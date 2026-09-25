class AddFamilyIdToAccountableAndTradeTables < ActiveRecord::Migration[7.2]
  # Same problem, same fix as AddFamilyIdToPolymorphicIndirectTables
  # (20260902010000) for transactions/valuations/receivables: these are the
  # remaining Accountable::TYPES (delegated_type :accountable on Account)
  # and the remaining Entryable::TYPES (delegated_type :entryable on Entry,
  # `trades` was the only one left after transactions/valuations) whose
  # family is only reachable by joining back to a parent row (Account /
  # Entry) that doesn't exist yet at the moment the child is first
  # inserted. A join-based RLS policy on these tables would hit the exact
  # INSERT-ordering bug that migration already fixed elsewhere.
  #
  # No app code change needed for population: Account#propagate_family_id_to_accountable
  # and Entry#propagate_family_id_to_entryable (app/models/concerns/
  # family_id_propagatable.rb, wired up via `propagates_family_id_to` in
  # account.rb/entry.rb) already run unconditionally for every accountable/
  # entryable type and are guarded by
  # `target.respond_to?(:family_id=)` -- once these columns exist, the
  # existing generic callback starts populating them on every new row with
  # zero additional code. The 10 models DO get a `belongs_to :family,
  # optional: true` (this commit) so fixtures/tests can set it via the
  # `family:` shorthand -- optional: true on purpose (not required like
  # Transaction/Valuation/Receivable's): unlike those 3, these 10 types are
  # instantiated standalone (no account/entry) throughout the existing test
  # suite (simplefin/coinbase/binance/coinstats importer and controller
  # tests build e.g. `Depository.create!(subtype: "checking")` on its own,
  # then attach it to an Account afterwards) -- making the association
  # required would fail all of those at validation, not just insert.
  # family_id stays nullable for the same reason: a NOT NULL column would
  # reject those same standalone creates outright. A row that's genuinely
  # created without ever going through Account (only happens in tests, not
  # in the app's real create paths) simply has family_id NULL and is
  # invisible under this etapa's `family_id = current_family_id()` policy --
  # fails closed, not open.
  ACCOUNTABLE_TABLES = {
    credit_cards: "CreditCard",
    cryptos: "Crypto",
    depositories: "Depository",
    investments: "Investment",
    loans: "Loan",
    other_assets: "OtherAsset",
    other_liabilities: "OtherLiability",
    properties: "Property",
    vehicles: "Vehicle"
  }.freeze

  def up
    ACCOUNTABLE_TABLES.each_key do |table|
      add_reference table, :family, type: :uuid, foreign_key: true, null: true
    end
    add_reference :trades, :family, type: :uuid, foreign_key: true, null: true

    ACCOUNTABLE_TABLES.each do |table, class_name|
      execute <<~SQL
        UPDATE #{table} SET family_id = accounts.family_id
        FROM accounts
        WHERE accounts.accountable_id = #{table}.id
          AND accounts.accountable_type = #{quote(class_name)};
      SQL
    end

    execute <<~SQL
      UPDATE trades SET family_id = accounts.family_id
      FROM entries
      JOIN accounts ON accounts.id = entries.account_id
      WHERE entries.entryable_id = trades.id
        AND entries.entryable_type = 'Trade';
    SQL

    # Deliberately NOT tightened to NOT NULL (see the class comment): these
    # 10 tables can legitimately hold rows with no account/entry yet
    # (standalone test fixtures) or with an orphaned one, and family_id
    # simply stays NULL for those -- invisible under RLS, not an error.
    # Surface any row a real backfill couldn't resolve, for awareness only.
    (ACCOUNTABLE_TABLES.keys + [ :trades ]).each do |table|
      orphan_count = select_value("SELECT COUNT(*) FROM #{table} WHERE family_id IS NULL")
      if orphan_count.to_i.positive?
        say "NOTE: #{table} has #{orphan_count} row(s) with family_id still NULL after backfill " \
            "(orphaned accountable/entryable, or pre-existing test data). They will be invisible " \
            "under this etapa's RLS policy for that table.", true
      end
    end
  end

  def down
    ACCOUNTABLE_TABLES.each_key { |table| remove_reference table, :family, foreign_key: true }
    remove_reference :trades, :family, foreign_key: true
  end
end
