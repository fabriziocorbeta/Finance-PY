# frozen_string_literal: true

require "test_helper"

class OauthMobileTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:empty)
    sign_in(@user)

    @oauth_app = Doorkeeper::Application.create!(
      name: "FinancePY Mobile App",
      redirect_uri: "financespy://oauth/callback",
      scopes: "read"
    )
  end

  test "mobile oauth authorization with custom scheme redirect" do
    get "/oauth/authorize", params: {
      client_id: @oauth_app.uid,
      redirect_uri: @oauth_app.redirect_uri,
      response_type: "code",
      scope: "read",
      display: "mobile"
    }

    assert_response :success

    # Check that Turbo is disabled in the form
    assert_match(/data-turbo="false"/, response.body)
    assert_match(/financespy:\/\/oauth\/callback/, response.body)
  end

  test "mobile oauth detects custom scheme in redirect_uri" do
    get "/oauth/authorize", params: {
      client_id: @oauth_app.uid,
      redirect_uri: "financespy://oauth/callback",
      response_type: "code",
      scope: "read"
    }

    assert_response :success

    # Should detect mobile flow from redirect_uri
    assert_match(/data-turbo="false"/, response.body)
  end

  test "mobile oauth authorization flow renders a native-redirect interstitial instead of a raw redirect" do
    post "/oauth/authorize", params: {
      client_id: @oauth_app.uid,
      redirect_uri: @oauth_app.redirect_uri,
      response_type: "code",
      scope: "read",
      display: "mobile"
    }

    # Custom Tabs providers (confirmed live on real Android devices: both
    # Chrome and Samsung Internet) silently ignore a raw HTTP 302 whose
    # Location header points at a non-http(s) scheme -- so for custom-scheme
    # redirect_uris this renders a 200 page that navigates there via JS/
    # meta-refresh instead, rather than issuing a redirect response.
    assert_response :success
    assert_match(/window\.location\.href\s*=\s*"financespy:\/\/oauth\/callback\?code=/, response.body)
    assert_match(/<meta http-equiv="refresh" content="0;url=financespy:\/\/oauth\/callback\?code=/, response.body)
  end

  test "mobile oauth authorization still issues a raw redirect for standard https redirect_uris" do
    https_app = Doorkeeper::Application.create!(
      name: "FinancePY Web Test App",
      redirect_uri: "https://finance.cd-co.com.py/callback",
      scopes: "read"
    )

    post "/oauth/authorize", params: {
      client_id: https_app.uid,
      redirect_uri: https_app.redirect_uri,
      response_type: "code",
      scope: "read"
    }

    # The native-redirect interstitial is scoped to non-http(s) schemes only
    # -- normal web OAuth clients keep the standard raw redirect behavior.
    assert_response :redirect
    assert response.location.start_with?("https://finance.cd-co.com.py/callback")
  end

  test "mobile oauth preserves display parameter through forms" do
    get "/oauth/authorize", params: {
      client_id: @oauth_app.uid,
      redirect_uri: @oauth_app.redirect_uri,
      response_type: "code",
      scope: "read",
      display: "mobile"
    }

    assert_response :success

    # Check that display parameter is preserved in hidden fields
    assert_match(/<input[^>]*name="display"[^>]*value="mobile"/, response.body)
  end
end
