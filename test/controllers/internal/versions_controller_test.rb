require "test_helper"

class Internal::VersionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @original_token = ENV["INTERNAL_VERSION_TOKEN"]
    @original_sha = ENV["BUILD_COMMIT_SHA"]
    ENV["INTERNAL_VERSION_TOKEN"] = "secret-internal-token-123"
  end

  teardown do
    ENV["INTERNAL_VERSION_TOKEN"] = @original_token
    ENV["BUILD_COMMIT_SHA"] = @original_sha
  end

  test "returns 503 service unavailable when INTERNAL_VERSION_TOKEN is not set" do
    ENV["INTERNAL_VERSION_TOKEN"] = nil
    get internal_version_url
    assert_response :service_unavailable
    json = JSON.parse(response.body)
    assert_equal "Internal version token not configured", json["error"]
  end

  test "returns 401 unauthorized without authorization token header" do
    get internal_version_url
    assert_response :unauthorized
    json = JSON.parse(response.body)
    assert_equal "unauthorized", json["error"]
  end

  test "returns 401 unauthorized with invalid authorization token header" do
    get internal_version_url, headers: { "X-Internal-Token" => "invalid-token" }
    assert_response :unauthorized
  end

  test "returns commit_sha and version with valid X-Internal-Token header" do
    ENV["BUILD_COMMIT_SHA"] = "abc123def456"
    get internal_version_url, headers: { "X-Internal-Token" => "secret-internal-token-123" }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "abc123def456", json["commit_sha"]
    assert json.key?("version")
  end

  test "returns commit_sha and version with valid Authorization Bearer header" do
    ENV["BUILD_COMMIT_SHA"] = "789ghi012jkl"
    get internal_version_url, headers: { "Authorization" => "Bearer secret-internal-token-123" }
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal "789ghi012jkl", json["commit_sha"]
    assert json.key?("version")
  end
end
