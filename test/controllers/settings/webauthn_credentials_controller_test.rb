require "test_helper"

class Settings::WebauthnCredentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_member)
    sign_in @user
    @user.setup_mfa!
    @user.enable_mfa!
  end

  # Removing a passkey is what a user does when a device is lost or suspected
  # compromised, so sessions established with that credential must not outlive
  # it. Without this the attacker's session survives the very action taken to
  # lock them out.
  test "destroying a passkey revokes other sessions while keeping the current one" do
    credential = @user.webauthn_credentials.create!(
      nickname: "Lost phone",
      credential_id: "revoke-on-destroy-credential",
      public_key: "public-key"
    )

    # sign_in already created the session this request runs under; capture it
    # before adding another, since both share a created_at second.
    current_session = @user.sessions.order(:created_at).last
    stale_session = RlsContext.with_auth_bypass(reason: "test_setup") { @user.sessions.create! }
    other_user_session = RlsContext.with_auth_bypass(reason: "test_setup") { users(:family_admin).sessions.create! }
    assert_not_equal stale_session.id, current_session.id

    delete settings_webauthn_credential_path(credential)

    assert_redirected_to settings_security_path
    assert_empty @user.reload.webauthn_credentials
    assert_not Session.exists?(stale_session.id), "Expected the user's other session to be destroyed"
    assert Session.exists?(current_session.id), "Expected the current session to be preserved"
    assert Session.exists?(other_user_session.id), "Expected another user's session to be untouched"
  end
end
