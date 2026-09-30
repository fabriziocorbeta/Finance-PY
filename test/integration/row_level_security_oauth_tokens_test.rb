require "test_helper"
require_relative "row_level_security_test"

# Regression test for oauth_access_tokens/oauth_access_grants: the mobile
# app's primary OAuth login/refresh path. Both tables are read/written by
# Doorkeeper's own mounted controllers (/oauth/authorize, /oauth/token,
# /oauth/revoke) via internal strategy classes that never set
# app.current_family_id, and by app call sites during
# login/signup/SSO/refresh/logout/deactivate -- none of which have a family
# context yet either. See DoorkeeperRlsController and the explicit
# with_auth_bypass wraps in base_controller.rb, auth_controller.rb,
# mobile_device.rb and user.rb.
#
# Also exercises the with_auth_bypass reentrancy fix (RlsContextTest covers
# the primitive directly): several of these call sites nest a bypass block
# inside another (e.g. Api::V1::BaseController#authenticate_oauth wraps
# Doorkeeper::AccessToken.by_token, which then calls User.auth_find_by_id,
# which wraps itself again).
class RowLevelSecurityOauthTokensTest < ActionDispatch::IntegrationTest
  setup do
    # MobileDevice.shared_oauth_application memoizes at the class level, so
    # it survives across tests' rolled-back transactions and would otherwise
    # point at an oauth_applications row that no longer exists in this test.
    MobileDevice.instance_variable_set(:@shared_oauth_application, nil)
  end

  test "oauth_access_tokens and oauth_access_grants have FORCE ROW LEVEL SECURITY set" do
    %w[oauth_access_tokens oauth_access_grants].each do |table|
      forced = ActiveRecord::Base.connection.select_value(<<~SQL)
        SELECT relforcerowsecurity FROM pg_class WHERE relname = '#{table}'
      SQL
      assert_equal true, forced, "Expected #{table} to have FORCE ROW LEVEL SECURITY set"
    end
  end

  test "Doorkeeper::AccessToken.by_token is a no-op under app_user with no context and no bypass, succeeds with bypass" do
    user = users(:family_admin)
    token = Doorkeeper::AccessToken.create!(
      application: MobileDevice.shared_oauth_application,
      resource_owner_id: user.id,
      expires_in: 2.hours.to_i,
      scopes: "read_write",
      use_refresh_token: true
    )
    plain_token = token.plaintext_token

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")

    assert_nil Doorkeeper::AccessToken.by_token(plain_token),
      "Sanity check: this documents why authenticate_oauth needs auth_bypass -- " \
      "if this ever returns non-nil, revisit this test"

    found = RlsContext.with_auth_bypass(reason: "test_verify") { Doorkeeper::AccessToken.by_token(plain_token) }
    assert_equal token, found
  ensure
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "MobileDevice#issue_token! and #revoke_all_tokens! work under app_user with real FORCE" do
    user = users(:family_admin)
    device = MobileDevice.create!(user: user, device_id: "rls-test-#{SecureRandom.hex(4)}", device_name: "RLS test device", device_type: "ios")

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")

    response = device.issue_token!
    assert response[:access_token].present?

    active_count = RlsContext.with_auth_bypass(reason: "test_verify") { device.active_tokens.count }
    assert_equal 1, active_count

    device.revoke_all_tokens!
    active_count_after_revoke = RlsContext.with_auth_bypass(reason: "test_verify") { device.active_tokens.count }
    assert_equal 0, active_count_after_revoke
  ensure
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "User#revoke_all_oauth_tokens! works under app_user with real FORCE" do
    user = users(:family_admin)
    token = Doorkeeper::AccessToken.create!(
      application: MobileDevice.shared_oauth_application,
      resource_owner_id: user.id,
      expires_in: 2.hours.to_i,
      scopes: "read_write"
    )

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")

    user.revoke_all_oauth_tokens!

    revoked_at = RlsContext.with_auth_bypass(reason: "test_verify") { token.reload.revoked_at }
    assert revoked_at.present?
  ensure
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "family A cannot see family B's oauth_access_tokens, and can see its own" do
    family_a = families(:dylan_family)
    user_a = users(:family_admin)
    family_b = Family.create!(name: "RLS oauth test family B", currency: "USD")
    user_b = User.create!(family: family_b, email: "rls_oauth_b@example.com", password: "password123")

    token_a = Doorkeeper::AccessToken.create!(application: MobileDevice.shared_oauth_application, resource_owner_id: user_a.id, expires_in: 2.hours.to_i, scopes: "read_write")
    token_b = Doorkeeper::AccessToken.create!(application: MobileDevice.shared_oauth_application, resource_owner_id: user_b.id, expires_in: 2.hours.to_i, scopes: "read_write")

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute(
      ActiveRecord::Base.sanitize_sql([ "SET app.current_family_id = ?", family_a.id ])
    )

    assert_equal token_a, Doorkeeper::AccessToken.find_by(id: token_a.id)
    assert_nil Doorkeeper::AccessToken.find_by(id: token_b.id)
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  test "DoorkeeperRlsController wraps every Doorkeeper-mounted action in RlsContext.with_auth_bypass" do
    assert_equal "DoorkeeperRlsController", Doorkeeper.config.base_controller.to_s.demodulize,
      "Doorkeeper.configure's base_controller must point at DoorkeeperRlsController " \
      "so /oauth/authorize, /oauth/token and /oauth/revoke all get the bypass"
    assert_includes Doorkeeper::ApplicationController.ancestors, DoorkeeperRlsController
  end

  test "authenticate_oauth wraps the Doorkeeper::AccessToken.by_token lookup in with_auth_bypass" do
    source = File.read(Rails.root.join("app/controllers/api/v1/base_controller.rb"))
    method_body = source[/def authenticate_oauth.*?\n    end/m]
    assert method_body, "authenticate_oauth method not found"
    assert_match(/with_auth_bypass\(reason: "api_oauth_token_lookup"\)/, method_body)
  end

  test "AuthController#refresh wraps the token exchange in with_auth_bypass" do
    source = File.read(Rails.root.join("app/controllers/api/v1/auth_controller.rb"))
    method_body = source[/def refresh.*?\n      end/m]
    assert method_body, "refresh method not found"
    assert_match(/with_auth_bypass\(reason: "refresh_token"\)/, method_body)
  end
end
