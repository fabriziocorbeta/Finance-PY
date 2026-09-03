class SwitchPolymorphicIndirectRlsToFamilyId < ActiveRecord::Migration[7.2]
  # Replaces the join-based policies (broken for INSERT, see
  # FixPolymorphicIndirectInsertPolicies for the reverted attempt and why)
  # with a direct family_id check -- exactly the same shape as every other
  # FORCE RLS table in this schema (accounts, budgets, categories, entries).
  # Safe to run only after app/models/entry.rb and app/models/account.rb's
  # before_validation callbacks are deployed and confirmed to populate
  # family_id on every new row (20260902010000 added and backfilled the
  # column; this migration is the one that starts actually depending on it).
  TABLES = %i[transactions valuations receivables].freeze

  def up
    TABLES.each do |table|
      execute "DROP POLICY IF EXISTS #{table}_family_isolation_policy ON #{table};"
      execute <<~SQL
        CREATE POLICY #{table}_family_isolation_policy ON #{table}
          FOR ALL
          USING (family_id = current_family_id())
          WITH CHECK (family_id = current_family_id());
      SQL
    end
  end

  def down
    original_conditions = {
      transactions: "id IN (SELECT entryable_id FROM entries WHERE entryable_type = 'Transaction' AND account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id()))",
      valuations: "id IN (SELECT entryable_id FROM entries WHERE entryable_type = 'Valuation' AND account_id IN (SELECT id FROM accounts WHERE family_id = current_family_id()))",
      receivables: "id IN (SELECT accountable_id FROM accounts WHERE accountable_type = 'Receivable' AND family_id = current_family_id())"
    }

    original_conditions.each do |table, policy_condition|
      execute "DROP POLICY IF EXISTS #{table}_family_isolation_policy ON #{table};"
      execute <<~SQL
        CREATE POLICY #{table}_family_isolation_policy ON #{table}
          FOR ALL
          USING (#{policy_condition})
          WITH CHECK (true);
      SQL
    end
  end
end
