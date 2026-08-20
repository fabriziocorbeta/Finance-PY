# frozen_string_literal: true

require "test_helper"

class Api::V1::BudgetsControllerTest < ActionDispatch::IntegrationTest
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

    # budgets(:one) ya existe para dylan_family (la familia de family_admin)
    # con exactamente este mes. Budget valida unicidad de start_date/end_date
    # por familia, asi que crear otro aca explotaba con
    # "Start date has already been taken". Se reusa el fixture.
    @budget = budgets(:one)
  end

  test "should list budgets" do
    get api_v1_budgets_url, headers: api_headers(@api_key)
    assert_response :success

    json_response = JSON.parse(response.body)
    assert json_response["data"].any? { |budget| budget["id"] == @budget.id }
    assert_equal @family.budgets.count, json_response["meta"]["total_count"]
  end

  test "should not list another family's budgets" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    other_budget = other_family.budgets.create!(
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      currency: other_family.currency
    )

    get api_v1_budgets_url, headers: api_headers(@api_key)
    assert_response :success

    budget_ids = JSON.parse(response.body)["data"].map { |b| b["id"] }
    assert_includes budget_ids, @budget.id
    assert_not_includes budget_ids, other_budget.id
  end

  test "should require authentication when listing budgets" do
    get api_v1_budgets_url

    assert_response :unauthorized
  end

  test "should require read scope when listing budgets" do
    api_key_without_read = api_key_without_read_scope

    get api_v1_budgets_url, headers: api_headers(api_key_without_read)

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_equal "insufficient_scope", json_response["error"]
  ensure
    api_key_without_read&.destroy
  end

  test "should show budget" do
    get api_v1_budget_url(id: @budget.id), headers: api_headers(@api_key)
    assert_response :success

    budget = JSON.parse(response.body)["data"]
    assert_equal @budget.id, budget["id"]
    assert_equal @budget.start_date.to_s, budget["start_date"]
    assert_equal @budget.end_date.to_s, budget["end_date"]
  end

  test "should require authentication when showing a budget" do
    get api_v1_budget_url(id: @budget.id)

    assert_response :unauthorized
  end

  test "should require read scope when showing a budget" do
    api_key_without_read = api_key_without_read_scope

    get api_v1_budget_url(id: @budget.id), headers: api_headers(api_key_without_read)

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_equal "insufficient_scope", json_response["error"]
  ensure
    api_key_without_read&.destroy
  end

  test "should not show another family's budget" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    other_budget = other_family.budgets.create!(
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      currency: other_family.currency
    )

    get api_v1_budget_url(id: other_budget.id), headers: api_headers(@api_key)
    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "not_found", json_response["error"]
  end

  private

    def api_key_without_read_scope
      ApiKey.new(
        user: @user,
        name: "No Read Key",
        scopes: [],
        display_key: "test_no_read_#{SecureRandom.hex(8)}",
        source: "mobile"
      ).tap { |api_key| api_key.save!(validate: false) }
    end

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
