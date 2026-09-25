class EnableRlsPolicyForFamilies < ActiveRecord::Migration[7.2]
  # `families` is the root of the whole tenancy graph (config/rls_inventory.yml
  # classification: root) -- there's no family_id column to check, the row's
  # own id IS the family_id every other table's policy points at. Same
  # ENABLE-without-FORCE reasoning as the direct-tables migration in this
  # batch: policies + tests this etapa, FORCE later.
  def up
    execute "ALTER TABLE families ENABLE ROW LEVEL SECURITY;"

    execute <<~SQL
      CREATE POLICY families_family_isolation_policy ON families
        FOR ALL
        USING (id = current_family_id())
        WITH CHECK (id = current_family_id());
    SQL
  end

  def down
    execute "DROP POLICY IF EXISTS families_family_isolation_policy ON families;"
    execute "ALTER TABLE families DISABLE ROW LEVEL SECURITY;"
  end
end
