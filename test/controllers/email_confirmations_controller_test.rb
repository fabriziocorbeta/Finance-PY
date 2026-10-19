require "test_helper"

class EmailConfirmationsControllerTest < ActionDispatch::IntegrationTest
  test "should get confirm" do
    user = users(:new_email)
    user.update!(unconfirmed_email: "new@example.com")
    token = user.generate_token_for(:email_confirmation)

    get new_email_confirmation_path(token: token)
    assert_redirected_to new_session_path
  end

  # `users` is FORCE RLS'd with family isolation and this action is
  # unauthenticated, so without an auth bypass the UPDATE matches zero rows and
  # still returns true -- the user is told the email was confirmed while it
  # silently was not.
  test "confirms the email under FORCE RLS when user is logged out" do
    require_relative "../integration/row_level_security_test"

    user = users(:new_email)
    RlsContext.with_auth_bypass(reason: "test_setup") { user.update!(unconfirmed_email: "new@example.com") }
    token = user.generate_token_for(:email_confirmation)

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")
    ActiveRecord::Base.connection.execute("RESET app.current_family_id")

    get new_email_confirmation_path(token: token)
    assert_redirected_to new_session_path

    reloaded = RlsContext.with_auth_bypass(reason: "test_verify") { User.find(user.id) }
    assert_equal "new@example.com", reloaded.email,
      "Expected the confirmed email to be persisted under FORCE RLS without family context"
    assert_nil reloaded.unconfirmed_email
  ensure
    ActiveRecord::Base.connection.execute("RESET app.current_family_id") rescue nil
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end

  # The email is the account's recovery identity, so a session or token issued
  # against the old address must not survive the change.
  test "confirming a new email revokes the user's sessions and tokens" do
    user = users(:new_email)
    RlsContext.with_auth_bypass(reason: "test_setup") { user.update!(unconfirmed_email: "revoked@example.com") }

    stale_session = RlsContext.with_auth_bypass(reason: "test_setup") { user.sessions.create! }
    other_user_session = RlsContext.with_auth_bypass(reason: "test_setup") { users(:family_member).sessions.create! }

    get new_email_confirmation_path(token: user.generate_token_for(:email_confirmation))
    assert_redirected_to new_session_path

    assert_not Session.exists?(stale_session.id), "Expected the user's pre-change session to be destroyed"
    assert Session.exists?(other_user_session.id), "Expected another user's session to be untouched"
  end
end
