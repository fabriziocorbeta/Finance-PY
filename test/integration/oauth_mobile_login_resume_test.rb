# frozen_string_literal: true

require "test_helper"

# Reproduces, end-to-end over real HTTP, the exact dead end found live
# tonight testing the native Android app on a fresh install: an
# unauthenticated user hits /oauth/authorize (what AuthRepository.kt's
# buildAuthorizationUrl() does), Doorkeeper bounces them to /sessions/new
# with no memory of the pending authorization, they log in with email+
# password, and -- before this fix -- SessionsController#create always
# redirected to root_path, discarding the OAuth request. The native app's
# financespy://oauth/callback intent-filter never fires, so it never gets a
# token: no chat, no account data, and (confirmed separately)
# WalletCaptureHandler's notification-triggered captures queue locally
# forever because AndroidTokenStorage never has an access_token to send
# with. oauth_basic_test.rb's "requires authentication" test asserted the
# broken first half of this (redirect to new_session_path, full stop) as
# correct behavior and never continued the flow -- that's how this
# shipped unnoticed.
class OauthMobileLoginResumeTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:empty)
    @oauth_app = Doorkeeper::Application.create!(
      name: "FinancePY Mobile App",
      redirect_uri: "financespy://oauth/callback",
      scopes: "read"
    )
    @authorize_params = {
      client_id: @oauth_app.uid,
      redirect_uri: @oauth_app.redirect_uri,
      response_type: "code",
      scope: "read",
      code_challenge: "test-challenge-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      code_challenge_method: "S256",
      state: "test-state-123"
    }
  end

  test "logging in resumes the pending mobile /oauth/authorize request instead of landing on the dashboard" do
    get "/oauth/authorize", params: @authorize_params
    assert_response :redirect
    assert_equal new_session_path, URI.parse(response.location).path
    follow_redirect!
    assert_response :success

    return_to = CGI.parse(URI.parse(response.request.url).query.to_s)["return_to"]&.first
    assert return_to.present?, "GET /sessions/new after an unauthenticated /oauth/authorize hit should carry return_to"
    assert_match %r{\A https?://.*/oauth/authorize\?}x, return_to,
      "return_to should point back at the original /oauth/authorize request, not somewhere else"

    post "/sessions", params: { email: @user.email, password: user_password_test }

    # Before the fix this was root_path. Now it must be back on
    # /oauth/authorize, continuing the Doorkeeper grant instead of dropping
    # the user on the web dashboard.
    assert_response :redirect
    refute_equal root_url, response.location,
      "login dropped the user on the dashboard instead of resuming the pending OAuth authorization"
    assert_match %r{/oauth/authorize\?}, response.location

    # Finish the resumed request as the now-authenticated user: landing back
    # on GET /oauth/authorize renders Doorkeeper's normal consent screen
    # (proving the full request -- client_id, PKCE challenge, state -- came
    # through intact, not just a bare redirect to nowhere); submitting it
    # (the user tapping "Authorize") is what actually issues the code.
    follow_redirect!
    assert_response :success
    assert_match(/Authorize.*FinancePY Mobile App/m, response.body)

    post "/oauth/authorize", params: @authorize_params
    assert_response :success
    assert_match(/financespy:\/\/oauth\/callback\?code=/, response.body)
  end

  test "return_to is consumed once and does not leak into the next unrelated login" do
    get "/oauth/authorize", params: @authorize_params
    follow_redirect!
    post "/sessions", params: { email: @user.email, password: user_password_test }
    assert_match %r{/oauth/authorize\?}, response.location

    delete session_path(@user.sessions.last)

    other_user = users(:family_admin)
    get new_session_path
    post "/sessions", params: { email: other_user.email, password: user_password_test }

    assert_redirected_to root_path,
      "a later, unrelated login must not be hijacked by a stale return_to from a previous OAuth attempt"
  end

  test "MFA users resume the pending /oauth/authorize request after verifying their code" do
    @user.setup_mfa!
    @user.enable_mfa!

    get "/oauth/authorize", params: @authorize_params
    follow_redirect!
    post "/sessions", params: { email: @user.email, password: user_password_test }
    assert_redirected_to verify_mfa_path

    follow_redirect!
    totp = ROTP::TOTP.new(@user.otp_secret, issuer: "Sure Finances")
    post verify_mfa_path, params: { code: totp.now }

    assert_response :redirect
    refute_equal root_url, response.location,
      "MFA verification dropped the user on the dashboard instead of resuming the pending OAuth authorization"
    assert_match %r{/oauth/authorize\?}, response.location
  end
end
