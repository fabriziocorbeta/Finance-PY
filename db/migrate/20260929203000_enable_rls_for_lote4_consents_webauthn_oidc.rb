class EnableRlsForLote4ConsentsWebauthnOidc < ActiveRecord::Migration[7.1]
  def up
    # 1. consents -- direct family_id column, no auth-bootstrap call site
    # (all reads/writes happen inside an authenticated request or inside a
    # RlsContext.with_family block -- see FamilyPurger / InactiveFamilyCleanerJob).
    execute <<-SQL
      DROP POLICY IF EXISTS consents_family_isolation_policy ON consents;
      CREATE POLICY consents_family_isolation_policy ON consents
      USING (family_id = current_family_id())
      WITH CHECK (family_id = current_family_id());
      ALTER TABLE consents ENABLE ROW LEVEL SECURITY;
      ALTER TABLE consents FORCE ROW LEVEL SECURITY;
    SQL

    # 2. webauthn_credentials -- read/written during the MFA step, before a
    # family context exists (MfaController#webauthn_options/verify_webauthn
    # are skip_authentication). Needs the same auth_bypass escape hatch as
    # users/sessions/api_keys/mobile_devices from Phase C (#392); those call
    # sites were wrapped in RlsContext.with_auth_bypass in this same PR.
    execute <<-SQL
      DROP POLICY IF EXISTS webauthn_credentials_family_isolation_policy ON webauthn_credentials;
      CREATE POLICY webauthn_credentials_family_isolation_policy ON webauthn_credentials
      USING (
        user_id IN (
          SELECT id FROM users WHERE family_id = current_family_id()
        )
        OR current_setting('app.rls_auth_bypass', true) = 'true'
      );
      ALTER TABLE webauthn_credentials ENABLE ROW LEVEL SECURITY;
      ALTER TABLE webauthn_credentials FORCE ROW LEVEL SECURITY;
    SQL

    # 3. oidc_identities -- read/written during SSO login and account
    # linking, before a family context exists (SessionsController#openid_connect,
    # OidcAccountsController#create_link/create_user are skip_authentication).
    # Same auth_bypass escape hatch; create_link's missing bypass wrap was
    # fixed in this same PR (create_user already had it).
    execute <<-SQL
      DROP POLICY IF EXISTS oidc_identities_family_isolation_policy ON oidc_identities;
      CREATE POLICY oidc_identities_family_isolation_policy ON oidc_identities
      USING (
        user_id IN (
          SELECT id FROM users WHERE family_id = current_family_id()
        )
        OR current_setting('app.rls_auth_bypass', true) = 'true'
      );
      ALTER TABLE oidc_identities ENABLE ROW LEVEL SECURITY;
      ALTER TABLE oidc_identities FORCE ROW LEVEL SECURITY;
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE consents NO FORCE ROW LEVEL SECURITY;
      ALTER TABLE consents DISABLE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS consents_family_isolation_policy ON consents;

      ALTER TABLE webauthn_credentials NO FORCE ROW LEVEL SECURITY;
      ALTER TABLE webauthn_credentials DISABLE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS webauthn_credentials_family_isolation_policy ON webauthn_credentials;

      ALTER TABLE oidc_identities NO FORCE ROW LEVEL SECURITY;
      ALTER TABLE oidc_identities DISABLE ROW LEVEL SECURITY;
      DROP POLICY IF EXISTS oidc_identities_family_isolation_policy ON oidc_identities;
    SQL
  end
end
