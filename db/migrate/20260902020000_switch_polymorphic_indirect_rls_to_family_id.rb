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

  # No safe down: the join-based policy this would restore is the exact
  # shape that made every insert into these 3 tables fail in production
  # (see the class comment). Restoring it -- even temporarily, even by
  # accident via a rollback of an unrelated later migration -- reintroduces
  # that outage. If you actually need to undo this, do it by hand and
  # decide deliberately what policy you want; don't let `db:rollback`
  # silently put the broken one back.
  def down
    raise ActiveRecord::IrreversibleMigration,
      "SwitchPolymorphicIndirectRlsToFamilyId cannot be safely reverted: " \
      "the old join-based RLS policy it would restore is what broke every " \
      "insert into transactions/valuations/receivables in the first place."
  end
end
