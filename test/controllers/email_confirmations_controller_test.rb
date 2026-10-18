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
end
