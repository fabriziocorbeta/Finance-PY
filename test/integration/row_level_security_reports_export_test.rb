require "test_helper"
require_relative "row_level_security_test"

# Regression test for ReportsController#export_transactions' API-key path
# (used for the Google Sheets integration) under real FORCE ROW LEVEL
# SECURITY. ReportsControllerTest's "export transactions with API key
# authentication" already covers this functionally, but under the default
# superuser-owning DB role, which bypasses RLS regardless of policy content
# -- same gap as the invitations and oauth_access_grants/tokens cases.
#
# authenticate_with_api_key's setup_current_context_for_api_key does
# @current_user.sessions.first_or_create! with no family context
# established yet (same bootstrap problem Authentication#authenticate_user!
# solves for session-cookie auth) -- sessions is FORCE RLS'd, scoped by the
# owning user's family, so without a bypass this INSERT violates the
# table's own RLS policy for every API-key-authenticated export request.
class RowLevelSecurityReportsExportTest < ActionDispatch::IntegrationTest
  test "export_transactions via API key succeeds under app_user with real FORCE RLS" do
    api_key = api_keys(:active_key)
    api_key.update!(source: "web") unless api_key.source == "web"

    RowLevelSecurityTest.ensure_non_superuser_role
    ActiveRecord::Base.connection.execute("SET ROLE app_user")

    get export_transactions_reports_path(
      format: :csv,
      period_type: :ytd,
      start_date: Date.current.beginning_of_year,
      end_date: Date.current
    ), headers: { "X-Api-Key" => api_key.plain_key }

    assert_response :ok, "API-key export must not fail under FORCE RLS: #{response.body}"
    assert_equal "text/csv", response.media_type
  ensure
    ActiveRecord::Base.connection.execute("RESET ROLE") rescue nil
  end
end
