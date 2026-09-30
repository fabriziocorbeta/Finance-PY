class EnableRlsForOauthAccessTokensAndGrants < ActiveRecord::Migration[7.1]
  def up
    # oauth_access_tokens.resource_owner_id / oauth_access_grants.resource_owner_id
    # are Doorkeeper's own varchar columns (its generic, ORM-agnostic
    # resource-owner storage) holding the stringified users.id -- cast to
    # text to compare.
    #
    # Both tables are read/written by Doorkeeper's own mounted controllers
    # (/oauth/authorize, /oauth/token, /oauth/revoke) via internal strategy
    # classes that never set app.current_family_id, and by a handful of app
    # call sites during login/signup/SSO/refresh/logout -- all now wrapped in
    # RlsContext.with_auth_bypass (DoorkeeperRlsController for the former,
    # explicit wraps in base_controller.rb/auth_controller.rb/mobile_device.rb
    # /user.rb for the latter). Same auth_bypass escape hatch as
    # users/sessions/api_keys from Phase C (#392).
    execute <<-SQL
      DROP POLICY IF EXISTS oauth_access_tokens_family_isolation_policy ON oauth_access_tokens;
      CREATE POLICY oauth_access_tokens_family_isolation_policy ON oauth_access_tokens
      USING (
        resource_owner_id IN (
          SELECT id::text FROM users WHERE family_id = current_family_id()
        )
        OR current_setting('app.rls_auth_bypass', true) = 'true'
      );
      ALTER TABLE oauth_access_tokens ENABLE ROW LEVEL SECURITY;
      ALTER TABLE oauth_access_tokens FORCE ROW LEVEL SECURITY;
    SQL

    execute <<-SQL
      DROP POLICY IF EXISTS oauth_access_grants_family_isolation_policy ON oauth_access_grants;
      CREATE POLICY oauth_access_grants_family_isolation_policy ON oauth_access_grants
      USING (
        resource_owner_id IN (
          SELECT id::text FROM users WHERE family_id = current_family_id()
        )
        OR current_setting('app.rls_auth_bypass', true) = 'true'
      );
      ALTER TABLE oauth_access_grants ENABLE ROW LEVEL SECURITY;
      ALTER TABLE oauth_access_grants FORCE ROW LEVEL SECURITY;
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE oauth_access_tokens NO FORCE ROW LEVEL SECURITY;
      ALTER TABLE oauth_access_tokens DISABLE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS oauth_access_tokens_family_isolation_policy ON oauth_access_tokens;

      ALTER TABLE oauth_access_grants NO FORCE ROW LEVEL SECURITY;
      ALTER TABLE oauth_access_grants DISABLE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS oauth_access_grants_family_isolation_policy ON oauth_access_grants;
    SQL
  end
end
