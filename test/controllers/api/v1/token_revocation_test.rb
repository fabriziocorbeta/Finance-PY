# frozen_string_literal: true

require "test_helper"

# A revoked OAuth token must stop working immediately (before, only expiry was
# checked, and tokens lived a year, so "revoke" and "change password" did nothing).
class Api::V1::TokenRevocationTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @app = Doorkeeper::Application.create!(
      name: "Test App", redirect_uri: "https://example.com/callback", scopes: "read read_write"
    )
    @token = Doorkeeper::AccessToken.create!(
      application: @app, resource_owner_id: @user.id, scopes: "read_write", expires_in: 2.hours.to_i
    )
  end

  def bearer(token) = { "Authorization" => "Bearer #{token.plaintext_token}" }

  test "a valid token works" do
    get api_v1_tags_url, headers: bearer(@token)
    assert_response :success
  end

  test "a revoked token is rejected" do
    @token.revoke

    get api_v1_tags_url, headers: bearer(@token)

    assert_response :unauthorized
  end

  test "an expired token is rejected" do
    @token.update_columns(created_at: 3.hours.ago)

    get api_v1_tags_url, headers: bearer(@token)

    assert_response :unauthorized
  end

  test "new tokens expire in hours, not a year" do
    assert_operator Doorkeeper.configuration.access_token_expires_in, :<=, 24.hours
  end

  test "revoke_all_oauth_tokens! ends every session of the user only" do
    other = Doorkeeper::AccessToken.create!(application: @app, resource_owner_id: users(:family_member).id, scopes: "read_write")

    @user.revoke_all_oauth_tokens!

    assert @token.reload.revoked?
    assert_not other.reload.revoked?
  end

  test "changing the password revokes the user's tokens" do
    sign_in @user

    patch password_url, params: { user: {
      password: "NewPassw0rd!xyz", password_confirmation: "NewPassw0rd!xyz", password_challenge: user_password_test
    } }

    assert @token.reload.revoked?
  end

  test "deactivating a user revokes their tokens" do
    @user.deactivate

    assert @token.reload.revoked?
  end
end
