class AllowAuthBypassForFamiliesRls < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      DROP POLICY IF EXISTS families_family_isolation_policy ON families;
      CREATE POLICY families_family_isolation_policy ON families
        FOR ALL
        USING (
          id = current_family_id()
          OR current_setting('app.rls_auth_bypass', true) = 'true'
        )
        WITH CHECK (
          id = current_family_id()
          OR current_setting('app.rls_auth_bypass', true) = 'true'
        );
    SQL
  end

  def down
    execute <<~SQL
      DROP POLICY IF EXISTS families_family_isolation_policy ON families;
      CREATE POLICY families_family_isolation_policy ON families
        FOR ALL
        USING (id = current_family_id())
        WITH CHECK (id = current_family_id());
    SQL
  end
end
