require "test_helper"
require_relative "row_level_security_test"

# Regression test for RLS lote 4 (consents, webauthn_credentials,
# oidc_identities): these three tables previously had no RLS at all (no
# ENABLE, no policy, no FORCE). webauthn_credentials and oidc_identities are
# both read/written during the MFA/SSO steps of login, before a family
# context exists (MfaController#webauthn_options/verify_webauthn and
# SessionsController#openid_connect / OidcAccountsController#create_link
# /create_user are all skip_authentication actions) -- the same bootstrap
# shape as the 2026-09-29 P0 on `families`, so both need the
# app.rls_auth_bypass escape hatch, not a plain family-scoped policy.
#
# Like the other RLS regression tests, this drives the exact mechanism
# under `app_user` -- the ordinary test suite runs as the migrator/owner
# role, which FORCE does not restrict.
class RowLevelSecurityLote4Test < ActionDispatch::IntegrationTest
  test "all lote 4 tables have FORCE ROW LEVEL SECURITY set" do
    %w[consents webauthn_credentials oidc_identities].each do |table|
      forced = ActiveRecord::Base.connection.select_value(<<~SQL)
        SELECT relforcerowsecurity FROM pg_class WHERE relname = '#{table}'
      SQL
      assert_equal true, forced, "Expected #{table} to have FORCE ROW LEVEL SECURITY set"
    end
  end

  test "consents is scoped by family_id with no bypass needed, and rejects cross-family reads" do
    own_consent = consents(:dylan_family_ai_processing)
    other_consent = consents(:empty_family_ai_processing)

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", own_consent.family_id ])
    )

    assert_equal own_consent, Consent.find_by(id: own_consent.id)
    assert_nil Consent.find_by(id: other_consent.id),
      "A consent belonging to a different family must not be readable"
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "webauthn_credentials lookup is a no-op under app_user with no context and no bypass, succeeds with bypass" do
    user = users(:family_admin)
    credential = WebauthnCredential.create!(
      user: user,
      nickname: "RLS lote4 test credential",
      credential_id: SecureRandom.base64(32),
      public_key: SecureRandom.base64(64)
    )

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    # No app.current_family_id, no app.rls_auth_bypass -- the exact state
    # MfaController#webauthn_options is in before RlsContext.with_auth_bypass.
    assert_nil WebauthnCredential.find_by(id: credential.id),
      "Sanity check: documents why the MFA webauthn step needs auth_bypass -- " \
      "if this ever returns non-nil, revisit this test"

    found = RlsContext.with_auth_bypass(reason: "test_verify") do
      WebauthnCredential.find_by(id: credential.id)
    end
    assert_equal credential, found
  ensure
    ActiveRecord::Base.connection.execute("RESET app.rls_auth_bypass") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "oidc_identities lookup is a no-op under app_user with no context and no bypass, succeeds with bypass" do
    identity = oidc_identities(:bob_google)

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    assert_nil OidcIdentity.find_by(id: identity.id),
      "Sanity check: documents why the SSO callback needs auth_bypass -- " \
      "if this ever returns non-nil, revisit this test"

    found = RlsContext.with_auth_bypass(reason: "test_verify") do
      OidcIdentity.find_by(id: identity.id)
    end
    assert_equal identity, found
  ensure
    ActiveRecord::Base.connection.execute("RESET app.rls_auth_bypass") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "MfaController wraps webauthn lookups and writes in RlsContext.with_auth_bypass" do
    source = File.read(Rails.root.join("app/controllers/mfa_controller.rb"))
    assert_match(/with_auth_bypass\(reason: "mfa_webauthn_options"\)/, source)
    assert_match(/with_auth_bypass\(reason: "mfa_verify_webauthn"\)/, source)
  end

  test "OidcAccountsController#create_link wraps identity creation in RlsContext.with_auth_bypass" do
    source = File.read(Rails.root.join("app/controllers/oidc_accounts_controller.rb"))
    method_body = source[/def create_link.*?\n  end/m]
    assert method_body, "create_link method not found"
    assert_match(/with_auth_bypass\(reason: "oidc_account_link"\)/, method_body)
  end
end
