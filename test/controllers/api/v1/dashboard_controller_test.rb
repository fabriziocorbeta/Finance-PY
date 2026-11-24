# frozen_string_literal: true

require "test_helper"

class Api::V1::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = @user.family

    @user.api_keys.active.destroy_all
    @read_api_key = ApiKey.create!(
      user: @user,
      name: "Dashboard Read Key",
      scopes: [ "read" ],
      source: "web",
      display_key: "test_dash_read_#{SecureRandom.hex(8)}"
    )

    Redis.new.del("api_rate_limit:#{@read_api_key.id}")
  end

  test "requires authentication" do
    get api_v1_dashboard_url
    assert_response :unauthorized
  end

  test "requires read scope" do
    no_scope_key = ApiKey.new(
      user: @user,
      name: "No Scope Key",
      scopes: [],
      display_key: "test_dash_no_scope_#{SecureRandom.hex(8)}",
      source: "mobile"
    ).tap { |k| k.save!(validate: false) }

    get api_v1_dashboard_url, headers: api_headers(no_scope_key)
    assert_response :forbidden
    assert_equal "insufficient_scope", JSON.parse(response.body)["error"]
  ensure
    no_scope_key&.destroy
  end

  test "returns dashboard payload for default current month period" do
    get api_v1_dashboard_url, headers: api_headers(@read_api_key)
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal @family.currency, body["currency"]
    assert body["greeting_name"].present?
    assert body.dig("period", "key").present?
    assert body.dig("period", "label").present?

    assert body["net_worth"].key?("amount")
    assert body["net_worth"].key?("amount_cents")
    assert_equal @family.currency, body.dig("net_worth", "currency")
    assert body.dig("net_worth", "series").is_a?(Array)

    assert body["cashflow_sankey"].key?("nodes")
    assert body["cashflow_sankey"].key?("links")
    assert body["outflows_donut"].key?("total")
    assert body["outflows_donut"].key?("categories")
    assert body.dig("balance_sheet", "classification_groups").is_a?(Array)
  end

  test "accepts explicit period and falls back gracefully on invalid period key" do
    get api_v1_dashboard_url(period: "last_30_days"), headers: api_headers(@read_api_key)
    assert_response :success
    assert_equal "last_30_days", JSON.parse(response.body).dig("period", "key")

    get api_v1_dashboard_url(period: "not_a_real_period"), headers: api_headers(@read_api_key)
    assert_response :success
    assert JSON.parse(response.body).dig("period", "key").present?
  end

  test "isolates balance sheet and outflows across families (RLS multi-tenancy)" do
    other_family = Family.create!(name: "Isolated PYG Family", currency: "PYG", locale: "es")
    other_user = User.create!(
      email: "dash_isolated_#{SecureRandom.hex(4)}@example.com",
      password: "SecurePass123!",
      family: other_family,
      first_name: "Isolated",
      last_name: "Owner",
      role: "admin"
    )
    other_account = other_family.accounts.create!(
      name: "Billetera Exclusiva",
      balance: 2_500_000,
      currency: "PYG",
      accountable: Depository.new,
      owner: other_user
    )
    other_key = ApiKey.create!(
      user: other_user,
      name: "Isolated Read Key",
      scopes: [ "read" ],
      source: "web",
      display_key: "test_dash_iso_#{SecureRandom.hex(8)}"
    )
    Redis.new.del("api_rate_limit:#{other_key.id}")

    get api_v1_dashboard_url, headers: api_headers(other_key)
    assert_response :success

    body = JSON.parse(response.body)
    assert_equal "PYG", body["currency"]

    returned_account_ids = body.dig("balance_sheet", "classification_groups")
      .flat_map { |cg| cg["account_groups"] || [] }
      .flat_map { |ag| ag["accounts"] || [] }
      .map { |acc| acc["id"] }

    assert_includes returned_account_ids, other_account.id
    @family.accounts.pluck(:id).each do |foreign_id|
      assert_not_includes returned_account_ids, foreign_id
    end
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
