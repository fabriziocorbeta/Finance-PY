# frozen_string_literal: true

require "test_helper"

class Api::V1::AuthHardeningTest < ActionDispatch::IntegrationTest
  setup do
    @family = families(:dylan_family)
    @admin = users(:family_admin)
    @member = users(:family_member)
    @member.api_keys.destroy_all
    @plain_token = "test_member_#{SecureRandom.hex(16)}"
    @member_api_key = ApiKey.create!(
      user: @member,
      name: "Member Key",
      scopes: [ "read_write" ],
      source: "web",
      key: @plain_token
    )
  end

  test "non-admin member cannot update family attributes" do
    old_currency = @family.currency

    patch "/api/v1/users/me",
      params: {
        family_attributes: {
          currency: "EUR"
        }
      },
      headers: { "X-Api-Key" => @plain_token }

    assert_response :success
    @family.reload
    assert_equal old_currency, @family.currency
  end

  test "admin can update family attributes" do
    @admin.api_keys.destroy_all
    admin_token = "test_admin_#{SecureRandom.hex(16)}"
    admin_key = ApiKey.create!(
      user: @admin,
      name: "Admin Key",
      scopes: [ "read_write" ],
      source: "web",
      key: admin_token
    )

    patch "/api/v1/users/me",
      params: {
        family_attributes: {
          currency: "EUR"
        }
      },
      headers: { "X-Api-Key" => admin_token }

    assert_response :success
    @family.reload
    assert_equal "EUR", @family.currency
  end

  test "deactivating user destroys all their active web sessions" do
    session1 = @member.sessions.create!
    session2 = @member.sessions.create!

    assert_equal 2, @member.sessions.count
    @member.deactivate
    assert_equal 0, @member.sessions.count
  end

  test "web session expires after inactivity timeout" do
    sign_in @member
    session = @member.sessions.last
    session.update_columns(updated_at: 31.minutes.ago)

    get root_url
    assert_redirected_to new_session_url
    assert_not Session.exists?(session.id)
  end

  test "disabling MFA requires correct password and totp" do
    sign_in @member
    @member.setup_mfa!
    @member.enable_mfa!

    # Sin password ni token -> rechazado
    delete disable_mfa_url
    assert_redirected_to settings_security_url
    assert @member.reload.otp_required?

    # Con password incorrecto -> rechazado
    totp = ROTP::TOTP.new(@member.otp_secret, issuer: "Sure Finances")
    delete disable_mfa_url, params: { password: "wrong", code: totp.now }
    assert_redirected_to settings_security_url
    assert @member.reload.otp_required?

    # Con password correcto y totp correcto -> desactivado
    delete disable_mfa_url, params: { password: user_password_test, code: totp.now }
    assert_redirected_to settings_security_url
    assert_not @member.reload.otp_required?
  end

  test "mcp endpoint sets RLS context for authenticated user via ApiKey" do
    post mcp_url,
      params: {
        jsonrpc: "2.0",
        id: 1,
        method: "initialize",
        params: {}
      }.to_json,
      headers: {
        "Authorization" => "Bearer #{@plain_token}",
        "Content-Type" => "application/json"
      }

    assert_response :success
    data = JSON.parse(response.body)
    assert_equal "2.0", data["jsonrpc"]
    assert_equal "sure", data.dig("result", "serverInfo", "name")
  end
end
