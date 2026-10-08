# frozen_string_literal: true

require "test_helper"

class OauthBasicTest < ActionDispatch::IntegrationTest
  test "oauth authorization endpoint requires authentication" do
    oauth_app = Doorkeeper::Application.create!(
      name: "Test API Client",
      redirect_uri: "https://client.example.com/callback",
      scopes: "read"
    )

    get "/oauth/authorize?client_id=#{oauth_app.uid}&redirect_uri=#{CGI.escape(oauth_app.redirect_uri)}&response_type=code&scope=read"

    # Should redirect to login page when not authenticated -- carrying
    # return_to so logging in can resume this exact /oauth/authorize request
    # instead of dropping the user on the dashboard (see
    # OauthMobileLoginResumeTest for the full round trip; this test used to
    # stop right here and assert that as the complete, correct behavior,
    # which is exactly how a real dead end for every native app login shipped
    # unnoticed).
    assert_response :redirect
    redirect_uri = URI.parse(response.location)
    assert_equal new_session_path, redirect_uri.path
    assert_match %r{\A https?://.*/oauth/authorize\?}x, CGI.parse(redirect_uri.query)["return_to"]&.first.to_s
  end

  test "oauth token endpoint exists and handles requests" do
    post "/oauth/token", params: {
      grant_type: "authorization_code",
      code: "invalid_code",
      redirect_uri: "https://example.com/callback",
      client_id: "invalid_client"
    }

    # Should return 401 for invalid client (correct OAuth behavior)
    assert_response :unauthorized
    response_body = JSON.parse(response.body)
    assert_equal "invalid_client", response_body["error"]
  end

  test "oauth applications can be created" do
    assert_difference("Doorkeeper::Application.count") do
      Doorkeeper::Application.create!(
        name: "Test App",
        redirect_uri: "https://example.com/callback",
        scopes: "read"
      )
    end
  end

  test "doorkeeper configuration is properly set up" do
    # Test that Doorkeeper is configured and working
    assert Doorkeeper.configuration.present?, "Doorkeeper configuration should exist"
    assert_equal 2.hours, Doorkeeper.configuration.access_token_expires_in
    assert_equal "read", Doorkeeper.configuration.default_scopes.first.to_s
  end
end
