class EnableRlsForPhaseCAuthTables < ActiveRecord::Migration[7.1]
  def up
    # 1. users
    execute <<-SQL
      DROP POLICY IF EXISTS users_family_isolation_policy ON users;
      CREATE POLICY users_family_isolation_policy ON users
      USING (
        family_id = current_family_id()
        OR current_setting('app.rls_auth_bypass', true) = 'true'
      );
      ALTER TABLE users ENABLE ROW LEVEL SECURITY;
      ALTER TABLE users FORCE ROW LEVEL SECURITY;
    SQL

    # 2. sessions
    execute <<-SQL
      DROP POLICY IF EXISTS sessions_family_isolation_policy ON sessions;
      CREATE POLICY sessions_family_isolation_policy ON sessions
      USING (
        user_id IN (
          SELECT id FROM users WHERE family_id = current_family_id()
        )
        OR current_setting('app.rls_auth_bypass', true) = 'true'
      );
      ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
      ALTER TABLE sessions FORCE ROW LEVEL SECURITY;
    SQL

    # 3. api_keys
    execute <<-SQL
      DROP POLICY IF EXISTS api_keys_family_isolation_policy ON api_keys;
      CREATE POLICY api_keys_family_isolation_policy ON api_keys
      USING (
        user_id IN (
          SELECT id FROM users WHERE family_id = current_family_id()
        )
        OR current_setting('app.rls_auth_bypass', true) = 'true'
      );
      ALTER TABLE api_keys ENABLE ROW LEVEL SECURITY;
      ALTER TABLE api_keys FORCE ROW LEVEL SECURITY;
    SQL

    # 4. mobile_devices
    execute <<-SQL
      DROP POLICY IF EXISTS mobile_devices_family_isolation_policy ON mobile_devices;
      CREATE POLICY mobile_devices_family_isolation_policy ON mobile_devices
      USING (
        user_id IN (
          SELECT id FROM users WHERE family_id = current_family_id()
        )
        OR current_setting('app.rls_auth_bypass', true) = 'true'
      );
      ALTER TABLE mobile_devices ENABLE ROW LEVEL SECURITY;
      ALTER TABLE mobile_devices FORCE ROW LEVEL SECURITY;
    SQL
  end

  def down
    # We leave the fallback to Etapa B (the policies without the bypass)
    execute <<-SQL
      ALTER TABLE users NO FORCE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS users_family_isolation_policy ON users;

      ALTER TABLE sessions NO FORCE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS sessions_family_isolation_policy ON sessions;

      ALTER TABLE api_keys NO FORCE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS api_keys_family_isolation_policy ON api_keys;

      ALTER TABLE mobile_devices NO FORCE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS mobile_devices_family_isolation_policy ON mobile_devices;

      -- Recreate the Etapa B baseline policies without auth_bypass
      CREATE POLICY users_family_isolation_policy ON users USING (family_id = current_family_id());
      CREATE POLICY sessions_family_isolation_policy ON sessions USING (user_id IN (SELECT id FROM users WHERE family_id = current_family_id()));
      CREATE POLICY api_keys_family_isolation_policy ON api_keys USING (user_id IN (SELECT id FROM users WHERE family_id = current_family_id()));
      CREATE POLICY mobile_devices_family_isolation_policy ON mobile_devices USING (user_id IN (SELECT id FROM users WHERE family_id = current_family_id()));
    SQL
  end
end
