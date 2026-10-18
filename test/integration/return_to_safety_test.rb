require "test_helper"

# `return_to` is attacker-controlled (it comes off the query string), gets
# stored in the session by StoreLocation, and is then handed to `redirect_to`
# by SessionsController#create and MfaController#verify_code.
#
# Rails' raise_on_open_redirects and the nonce-only CSP each happen to block
# one of the two attacks today, but both are one config flip away
# (`allow_other_host: true`, `CSP_REPORT_ONLY=true`), so the value is validated
# on the way in and on the way out. These tests pin that down.
class ReturnToSafetyTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
  end

  # "//evil.com" is the one that mattered: URI.parse reports no scheme and host
  # "evil.com", and it starts with "/", so a check that only looks at
  # `uri.scheme` lets it through -- and the browser resolves it to an external
  # host. Two of the three copies of this validator had exactly that hole.
  REJECTED = [
    "//evil.com",
    "//evil.com/path",
    "https://evil.com",
    "javascript:alert(document.domain)",
    "evil.com"
  ].freeze

  test "unsafe return_to never reaches the post-login redirect" do
    REJECTED.each do |value|
      session = open_session
      session.get new_session_path(return_to: value)
      session.post sessions_path, params: { email: @user.email, password: user_password_test }

      assert_equal "http://www.example.com/", session.response.location,
        "expected #{value.inspect} to be rejected and login to land on root"
    end
  end

  test "a root-relative return_to is still honored" do
    session = open_session
    session.get new_session_path(return_to: "/accounts")
    session.post sessions_path, params: { email: @user.email, password: user_password_test }

    assert_equal "http://www.example.com/accounts", session.response.location
  end

  # Doorkeeper stores the whole /oauth/authorize url, so a same-host absolute
  # url must survive -- native-app login resumes through it. Tightening this to
  # paths only broke oauth_mobile_login_resume_test, which asserts that shape.
  test "a same-host absolute return_to is still honored" do
    session = open_session
    session.get new_session_path(return_to: "http://www.example.com/oauth/authorize?client_id=abc")
    session.post sessions_path, params: { email: @user.email, password: user_password_test }

    assert_equal "http://www.example.com/oauth/authorize?client_id=abc", session.response.location,
      "native-app login resume depends on same-host absolute urls still working"
  end
end
