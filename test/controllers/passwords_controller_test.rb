require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
  end

  test "update changes password and revokes other sessions while keeping current session" do
    other_session = RlsContext.with_auth_bypass(reason: "test_setup") { @user.sessions.create! }
    other_user_session = RlsContext.with_auth_bypass(reason: "test_setup") { users(:family_member).sessions.create! }

    sign_in @user
    current_session = @user.sessions.order(:created_at).last
    assert_not_equal other_session.id, current_session.id

    patch password_path, params: {
      user: {
        password: "NewPassword123!",
        password_confirmation: "NewPassword123!",
        password_challenge: user_password_test
      }
    }

    assert_redirected_to root_path
    assert_not Session.exists?(other_session.id), "Expected other session for the user to be destroyed"
    assert Session.exists?(current_session.id), "Expected current session to be preserved"
    assert Session.exists?(other_user_session.id), "Expected another user's session to be untouched"
  end
end
