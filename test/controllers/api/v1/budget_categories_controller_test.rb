# frozen_string_literal: true

require "test_helper"

class Api::V1::BudgetCategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:family_admin)
    @family = @user.family

    @write_api_key = ApiKey.create!(
      user: @user,
      name: "Test Write Key",
      scopes: [ "read_write" ],
      source: "mobile",
      display_key: "test_write_#{SecureRandom.hex(8)}"
    )

    Redis.new.del("api_rate_limit:#{@write_api_key.id}")

    @budget = budgets(:one)
    @budget_category = @budget.budget_categories.create!(
      category: categories(:food_and_drink),
      budgeted_spending: 500,
      currency: "USD"
    )
  end

  test "should return 409 conflict if last_updated_at is older than budget_category updated_at" do
    old_updated_at = @budget_category.updated_at.to_i - 10

    # Update it in the background to simulate Client B
    @budget_category.touch

    patch api_v1_budget_budget_category_url(budget_id: @budget.id, id: @budget_category.id),
          params: { budget_category: { budgeted_spending: 5000 }, last_updated_at: old_updated_at },
          headers: api_headers(@write_api_key)

    assert_response :conflict
    json_response = JSON.parse(response.body)
    assert_equal "conflict", json_response["error"]
    assert_equal "Otra persona de tu familia modificó este presupuesto, recargá la pantalla.", json_response["message"]
  end

  test "should update successfully if last_updated_at is equal to budget_category updated_at" do
    current_updated_at = @budget_category.updated_at.to_i

    patch api_v1_budget_budget_category_url(budget_id: @budget.id, id: @budget_category.id),
          params: { budget_category: { budgeted_spending: 5500 }, last_updated_at: current_updated_at },
          headers: api_headers(@write_api_key)

    assert_response :success
    @budget_category.reload
    assert_equal 5500, @budget_category.budgeted_spending
  end

  test "should update successfully if last_updated_at is newer than budget_category updated_at" do
    new_updated_at = @budget_category.updated_at.to_i + 10

    patch api_v1_budget_budget_category_url(budget_id: @budget.id, id: @budget_category.id),
          params: { budget_category: { budgeted_spending: 6500 }, last_updated_at: new_updated_at },
          headers: api_headers(@write_api_key)

    assert_response :success
    @budget_category.reload
    assert_equal 6500, @budget_category.budgeted_spending
  end

  test "should update successfully if last_updated_at is absent" do
    patch api_v1_budget_budget_category_url(budget_id: @budget.id, id: @budget_category.id),
          params: { budget_category: { budgeted_spending: 7500 } },
          headers: api_headers(@write_api_key)

    assert_response :success
    @budget_category.reload
    assert_equal 7500, @budget_category.budgeted_spending
  end

  private

    def api_headers(api_key)
      { "X-Api-Key" => api_key.plain_key }
    end
end
