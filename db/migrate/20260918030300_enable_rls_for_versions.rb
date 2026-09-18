class EnableRlsForVersions < ActiveRecord::Migration[7.2]
  # versions.family_id is populated directly by PaperTrail (see
  # `has_paper_trail meta: { family_id: :family_id }` on Entry/Account/
  # Holding) -- same direct-column shape as accounts/budgets/goals, not
  # the join-based shape entries/budget_categories use. Simpler and avoids
  # the INSERT-time join problem documented in
  # SwitchPolymorphicIndirectRlsToFamilyId.
  def up
    execute "ALTER TABLE versions ENABLE ROW LEVEL SECURITY;"
    execute <<~SQL
      CREATE POLICY versions_family_isolation_policy ON versions
        FOR ALL
        USING (family_id = current_family_id())
        WITH CHECK (family_id = current_family_id());
    SQL
  end

  def down
    execute "DROP POLICY IF EXISTS versions_family_isolation_policy ON versions;"
    execute "ALTER TABLE versions DISABLE ROW LEVEL SECURITY;"
  end
end
