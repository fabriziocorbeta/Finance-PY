require "test_helper"

class CspReportsControllerTest < ActionDispatch::IntegrationTest
  test "logs valid CSP violation report and returns 204" do
    payload = { "csp-report" => { "blocked-uri" => "https://evil.example/script.js", "violated-directive" => "script-src" } }.to_json
    Rails.logger.expects(:warn).with(includes("[CSP Violation]")).once

    post "/csp_reports", params: payload, headers: { "CONTENT_TYPE" => "application/csp-report" }
    assert_response :no_content
  end

  test "ignores oversized CSP report without parsing or logging" do
    oversized = "A" * (CspReportsController::MAX_REPORT_BYTES + 1)
    JSON.expects(:parse).never
    Rails.logger.expects(:warn).never

    post "/csp_reports", params: oversized, headers: { "CONTENT_TYPE" => "application/csp-report" }
    assert_response :no_content
  end

  test "handles malformed JSON and returns 204" do
    post "/csp_reports", params: "{not-json", headers: { "CONTENT_TYPE" => "application/csp-report" }
    assert_response :no_content
  end
end
