# frozen_string_literal: true

require "test_helper"

class Api::V1::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = @user.family

    @user.api_keys.active.destroy_all
    @api_key = ApiKey.create!(
      user: @user,
      name: "Test Read Key",
      scopes: [ "read" ],
      source: "web",
      display_key: "test_read_#{SecureRandom.hex(8)}"
    )

    Redis.new.del("api_rate_limit:#{@api_key.id}")
  end

  test "should get reports summary with default period (monthly)" do
    get api_v1_reports_summary_url, headers: api_headers(@api_key)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "monthly", json_response.dig("period", "type")
    assert_not_nil json_response["summary"]
    assert_not_nil json_response["trends"]
    assert_not_nil json_response["net_worth"]
    assert_not_nil json_response["transactions_breakdown"]

    assert json_response["summary"].key?("income")
    assert json_response["summary"].key?("expense")
    assert json_response["summary"].key?("net_savings")
    assert json_response["summary"].key?("income_change_pct")
    assert json_response["summary"].key?("expense_change_pct")

    assert json_response["transactions_breakdown"].key?("income")
    assert json_response["transactions_breakdown"].key?("expense")
  end

  test "should get reports summary with quarterly period" do
    get api_v1_reports_summary_url(period_type: "quarterly"), headers: api_headers(@api_key)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "quarterly", json_response.dig("period", "type")
  end

  test "should get reports summary with custom period" do
    start_d = 2.months.ago.to_date.to_s
    end_d = Date.current.to_s

    get api_v1_reports_summary_url(period_type: "custom", start_date: start_d, end_date: end_d), headers: api_headers(@api_key)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal "custom", json_response.dig("period", "type")
    assert_equal start_d, json_response.dig("period", "start_date")
    assert_equal end_d, json_response.dig("period", "end_date")
  end

  test "should require authentication when fetching reports summary" do
    get api_v1_reports_summary_url
    assert_response :unauthorized
  end

  test "should require read scope when fetching reports summary" do
    api_key_without_read = ApiKey.new(
      user: @user,
      name: "No Read Key",
      scopes: [],
      display_key: "test_no_read_#{SecureRandom.hex(8)}",
      source: "mobile"
    ).tap { |k| k.save!(validate: false) }

    get api_v1_reports_summary_url, headers: api_headers(api_key_without_read)
    assert_response :forbidden

    json_response = JSON.parse(response.body)
    assert_equal "insufficient_scope", json_response["error"]
  ensure
    api_key_without_read&.destroy
  end

  test "should respect RLS multi-tenant scoping for family data" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    other_user = User.create!(
      email: "other@example.com",
      password: "password123",
      family: other_family,
      first_name: "Other",
      last_name: "User"
    )
    other_key = ApiKey.create!(
      user: other_user,
      name: "Other Key",
      scopes: [ "read" ],
      source: "web",
      display_key: "other_read_#{SecureRandom.hex(8)}"
    )

    get api_v1_reports_summary_url, headers: api_headers(other_key)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_equal 0.0, json_response.dig("summary", "income")
    assert_equal 0.0, json_response.dig("summary", "expense")
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
