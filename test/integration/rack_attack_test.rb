# frozen_string_literal: true

require "test_helper"

class RackAttackTest < ActionDispatch::IntegrationTest
  test "rack attack is configured" do
    # Verify Rack::Attack is enabled in middleware stack
    middleware_classes = Rails.application.middleware.map(&:klass)
    assert_includes middleware_classes, Rack::Attack, "Rack::Attack should be in middleware stack"
  end

  test "oauth token endpoint has rate limiting configured" do
    # Test that the throttle is configured (we don't need to trigger it)
    throttles = Rack::Attack.throttles.keys
    assert_includes throttles, "oauth/token", "OAuth token endpoint should have rate limiting"
  end

  test "api requests have rate limiting configured" do
    # Test that API rate limiting is configured
    throttles = Rack::Attack.throttles.keys
    assert_includes throttles, "api/requests", "API requests should have rate limiting"
  end

  test "authentication entry points are throttled" do
    names = Rack::Attack.throttles.keys
    %w[mfa/verify_code login/email password_reset/ip password_reset/email signup/ip api_auth/ip].each do |name|
      assert_includes names, name
    end
  end

  test "cost-sensitive endpoints are throttled" do
    names = Rack::Attack.throttles.keys
    %w[chats/create messages/create imports/create statement_imports/create family_exports/create mcp/requests].each do |name|
      assert_includes names, name
    end
  end

  test "repeated chat creation from the same actor is rejected with 429" do
    with_rack_attack do
      20.times { post "/chats", params: { chat: { content: "hi" } } }
      post "/chats", params: { chat: { content: "hi" } }

      assert_response :too_many_requests
    end
  end

  test "repeated message creation on the same chat is rejected with 429" do
    with_rack_attack do
      60.times { post "/chats/1/messages", params: { message: { content: "hi" } } }
      post "/chats/1/messages", params: { message: { content: "hi" } }

      assert_response :too_many_requests
    end
  end

  test "repeated family export requests are rejected with 429" do
    with_rack_attack do
      5.times { post "/family_exports" }
      post "/family_exports"

      assert_response :too_many_requests
    end
  end

  test "repeated MCP requests from the same token are rejected with 429" do
    with_rack_attack do
      headers = { "HTTP_AUTHORIZATION" => "Bearer some-token", "CONTENT_TYPE" => "application/json" }
      120.times { post "/mcp", params: '{"jsonrpc":"2.0","id":1,"method":"ping"}', headers: headers }
      post "/mcp", params: '{"jsonrpc":"2.0","id":1,"method":"ping"}', headers: headers

      assert_response :too_many_requests
    end
  end

  test "chat throttle keys by session cookie, not shared IP" do
    with_rack_attack do
      # Two different sessions from the same IP must not share one bucket.
      20.times do
        post "/chats", params: { chat: { content: "hi" } },
                        headers: { "REMOTE_ADDR" => "10.2.0.1", "Cookie" => "session_token=actor-one" }
      end
      post "/chats", params: { chat: { content: "hi" } },
                      headers: { "REMOTE_ADDR" => "10.2.0.1", "Cookie" => "session_token=actor-two" }

      # Different session cookie -> different actor bucket -> not throttled,
      # regardless of whatever unauthenticated status the app itself returns.
      assert_not_equal 429, response.status
    end
  end

  test "repeated TOTP submissions from one IP are rejected with 429" do
    with_rack_attack do
      10.times { post "/mfa/verify", params: { code: "000000" } }
      post "/mfa/verify", params: { code: "000000" }

      assert_response :too_many_requests
    end
  end

  test "password reset requests for one email are limited even across IPs" do
    with_rack_attack do
      3.times { |i| post "/password_reset", params: { email: "victim@example.com" }, headers: { "REMOTE_ADDR" => "10.0.0.#{i + 1}" } }
      post "/password_reset", params: { email: "victim@example.com" }, headers: { "REMOTE_ADDR" => "10.0.9.9" }

      assert_response :too_many_requests
    end
  end

  test "JSON API login attempts are throttled per email too" do
    with_rack_attack do
      10.times do |i|
        post "/api/v1/auth/login", params: { email: "victim@example.com", password: "x" }.to_json,
             headers: { "CONTENT_TYPE" => "application/json", "REMOTE_ADDR" => "10.1.0.#{i + 1}" }
      end
      post "/api/v1/auth/login", params: { email: "victim@example.com", password: "x" }.to_json,
           headers: { "CONTENT_TYPE" => "application/json", "REMOTE_ADDR" => "10.1.9.9" }

      assert_response :too_many_requests
    end
  end

  private

    def with_rack_attack
      previous_enabled = Rack::Attack.enabled
      previous_store = Rack::Attack.cache.store
      Rack::Attack.enabled = true
      Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
      yield
    ensure
      Rack::Attack.enabled = previous_enabled
      Rack::Attack.cache.store = previous_store
    end
end
