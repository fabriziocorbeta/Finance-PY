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
    access_token_record = Doorkeeper::AccessToken.create!(
      application: MobileDevice.shared_oauth_application,
      resource_owner_id: user.id,
      expires_in: 2.hours.to_i,
      scopes: "read_write",
      use_refresh_token: true
    )
    plain_token = access_token_record.plaintext_token

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")

    assert_nil Doorkeeper::AccessToken.by_token(plain_token),
      "Sanity check: this documents why authenticate_oauth needs auth_bypass -- " \
      "if this ever returns non-nil, revisit this test"

    found = RlsContext.with_auth_bypass(reason: "test_verify") { Doorkeeper::AccessToken.by_token(plain_token) }
    assert_equal access_token_record, found
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
    access_token_record = Doorkeeper::AccessToken.create!(
      application: MobileDevice.shared_oauth_application,
      resource_owner_id: user.id,
      expires_in: 2.hours.to_i,
      scopes: "read_write"
    )

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")

    user.revoke_all_oauth_tokens!

    revoked_at = RlsContext.with_auth_bypass(reason: "test_verify") { access_token_record.reload.revoked_at }
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

  test "DoorkeeperRlsController wraps Doorkeeper::ApplicationController actions (/oauth/authorize) in RlsContext.with_auth_bypass" do
    assert_equal "DoorkeeperRlsController", Doorkeeper.config.base_controller.to_s.demodulize,
      "Doorkeeper.configure's base_controller must point at DoorkeeperRlsController " \
      "so /oauth/authorize gets the bypass"
    assert_includes Doorkeeper::ApplicationController.ancestors, DoorkeeperRlsController
  end

  # Doorkeeper::TokensController (/oauth/token, /oauth/revoke, /oauth/introspect)
  # does NOT inherit from Doorkeeper::ApplicationController -- it's hardcoded
  # to Doorkeeper::ApplicationMetalController, which resolves the SEPARATE
  # `base_metal_controller` config key (default plain ActionController::API,
  # no bypass at all). The test above only ever proved the /oauth/authorize
  # half was wrapped; this is the other half, and its absence is exactly what
  # let every token exchange silently 100%-fail with invalid_grant after
  # oauth_access_tokens/oauth_access_grants went FORCE RLS on 2026-09-30,
  # undetected because this test's wrong assertion and the happy-path gap
  # below both passed CI.
  test "DoorkeeperRlsMetalController wraps Doorkeeper::ApplicationMetalController actions (/oauth/token) in RlsContext.with_auth_bypass" do
    assert_equal "DoorkeeperRlsMetalController", Doorkeeper.config.base_metal_controller.to_s.demodulize,
      "Doorkeeper.configure's base_metal_controller must point at DoorkeeperRlsMetalController " \
      "so /oauth/token and /oauth/revoke get the bypass too"
    assert_includes Doorkeeper::ApplicationMetalController.ancestors, DoorkeeperRlsMetalController
  end

  # End-to-end happy path, under real FORCE RLS as the non-superuser app
  # role -- the thing no existing oauth test ever did. oauth_basic_test.rb's
  # "/oauth/token endpoint exists" only ever posted an invalid_code/
  # invalid_client pair (fails before any table read matters), and every
  # oauth_mobile_test.rb case stops at /oauth/authorize. Mirrors the real
  # Android client: PKCE S256, MobileDevice.shared_oauth_application,
  # custom-scheme redirect_uri.
  test "a full PKCE authorization_code exchange succeeds end-to-end under FORCE RLS as app_user" do
    user = users(:family_admin)
    sign_in(user)

    verifier = SecureRandom.alphanumeric(64)
    challenge = Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
    app = MobileDevice.shared_oauth_application

    post "/oauth/authorize", params: {
      client_id: app.uid,
      redirect_uri: app.redirect_uri,
      response_type: "code",
      scope: "read_write",
      code_challenge: challenge,
      code_challenge_method: "S256",
      display: "mobile"
    }
    assert_response :success
    code = response.body[/financespy:\/\/oauth\/callback\?code=([^"&]+)/, 1]
    assert code.present?, "Expected an authorization code in the mobile redirect interstitial: #{response.body}"

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    # The real Android client hits /oauth/token as a separate, unauthenticated
    # request -- no session cookie, no app.current_family_id ever set on
    # whatever connection services it. In production the connection-pool
    # checkin/checkout hooks (rls_connection_safety.rb) guarantee that; here,
    # transactional-fixture tests keep ONE connection checked out for the
    # whole test, so the family context /oauth/authorize just set above
    # would otherwise leak into this call and let the policy pass on
    # family membership alone, masking exactly the bug this test exists to
    # catch. Reset explicitly to reproduce the real boundary.
    ActiveRecord::Base.connection.execute("RESET app.current_family_id")

    post "/oauth/token", params: {
      grant_type: "authorization_code",
      client_id: app.uid,
      code: code,
      redirect_uri: app.redirect_uri,
      code_verifier: verifier
    }

    assert_response :success, "Token exchange failed: #{response.body}"
    body = JSON.parse(response.body)
    assert body["access_token"].present?
    assert body["refresh_token"].present?
  ensure
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
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
