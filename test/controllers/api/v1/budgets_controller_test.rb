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

    @write_api_key = ApiKey.create!(
      user: @user,
      name: "Test Write Key",
      scopes: [ "read_write" ],
      source: "mobile",
      display_key: "test_write_#{SecureRandom.hex(8)}"
    )

    Redis.new.del("api_rate_limit:#{@api_key.id}")
    Redis.new.del("api_rate_limit:#{@write_api_key.id}")

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
    assert_equal @budget.actual_spending, budget["actual_spending"]
    assert_equal @budget.allocated_spending, budget["allocated_spending"]
    assert_equal @budget.available_to_spend, budget["available_to_spend"]
    assert_equal @budget.percent_of_budget_spent, budget["percent_of_budget_spent"]
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

  test "should create budget with read_write scope" do
    start_date = Date.new(2030, 1, 1)
    end_date = start_date.end_of_month

    assert_difference -> { @family.budgets.count }, 1 do
      post api_v1_budgets_url,
           params: { budget: { start_date: start_date.to_s, end_date: end_date.to_s, budgeted_spending: 1000, expected_income: 2000 } },
           headers: api_headers(@write_api_key)
    end

    assert_response :created
    json_response = JSON.parse(response.body)["data"]
    assert_equal start_date.to_s, json_response["start_date"]
    assert_equal end_date.to_s, json_response["end_date"]
    assert_equal "1000.0", json_response["budgeted_spending"]
    assert_equal "2000.0", json_response["expected_income"]
  end

  test "should fail to create budget without write scope" do
    post api_v1_budgets_url,
         params: { budget: { start_date: "2030-02-01", end_date: "2030-02-28", budgeted_spending: 1000 } },
         headers: api_headers(@api_key)

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_equal "insufficient_scope", json_response["error"]
  end

  test "should fail to create budget with duplicate dates" do
    post api_v1_budgets_url,
         params: { budget: { start_date: @budget.start_date.to_s, end_date: @budget.end_date.to_s } },
         headers: api_headers(@write_api_key)

    assert_response :unprocessable_entity
    json_response = JSON.parse(response.body)
    assert_equal "validation_failed", json_response["error"]
  end

  test "should require authentication when creating a budget" do
    post api_v1_budgets_url,
         params: { budget: { start_date: "2030-03-01", end_date: "2030-03-31" } }

    assert_response :unauthorized
  end

  test "should update budget with read_write scope" do
    patch api_v1_budget_url(id: @budget.id),
          params: { budget: { budgeted_spending: 5000, expected_income: 6000 } },
          headers: api_headers(@write_api_key)

    assert_response :success
    json_response = JSON.parse(response.body)["data"]
    assert_equal "5000.0", json_response["budgeted_spending"]
    assert_equal "6000.0", json_response["expected_income"]

    @budget.reload
    assert_equal 5000, @budget.budgeted_spending
    assert_equal 6000, @budget.expected_income
  end

  test "should fail to update budget without write scope" do
    patch api_v1_budget_url(id: @budget.id),
          params: { budget: { budgeted_spending: 5000 } },
          headers: api_headers(@api_key)

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_equal "insufficient_scope", json_response["error"]
  end

  test "should not update another family's budget" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    other_budget = other_family.budgets.create!(
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      currency: other_family.currency
    )

    patch api_v1_budget_url(id: other_budget.id),
          params: { budget: { budgeted_spending: 5000 } },
          headers: api_headers(@write_api_key)

    assert_response :not_found
    json_response = JSON.parse(response.body)
    assert_equal "not_found", json_response["error"]
  end

  test "should destroy budget with read_write scope" do
    destroy_budget = @family.budgets.create!(
      start_date: Date.new(2030, 4, 1),
      end_date: Date.new(2030, 4, 30),
      currency: @family.currency
    )

    assert_difference -> { @family.budgets.count }, -1 do
      delete api_v1_budget_url(id: destroy_budget.id), headers: api_headers(@write_api_key)
    end

    assert_response :no_content
    assert_nil Budget.find_by(id: destroy_budget.id)
  end

  test "should fail to destroy budget without write scope" do
    delete api_v1_budget_url(id: @budget.id), headers: api_headers(@api_key)

    assert_response :forbidden
    json_response = JSON.parse(response.body)
    assert_equal "insufficient_scope", json_response["error"]
  end

  test "should not destroy another family's budget" do
    other_family = Family.create!(name: "Other Family", currency: "USD", locale: "en")
    other_budget = other_family.budgets.create!(
      start_date: Date.current.beginning_of_month,
      end_date: Date.current.end_of_month,
      currency: other_family.currency
    )

    delete api_v1_budget_url(id: other_budget.id), headers: api_headers(@write_api_key)

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
