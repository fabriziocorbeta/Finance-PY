require "test_helper"

class BudgetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @budget = budgets(:one)
  end

  test "show renders budget page and fragment cached sidebar and donut" do
    get budget_path(month_year: @budget.to_param)
    assert_response :success
    assert_includes @response.body, "account-sidebar-tabs"
    assert_includes @response.body, "sidebar-active-account"
  end

  test "index redirects to current month budget" do
    get budgets_path
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  test "update fails with 409 conflict if last_updated_at is older than updated_at" do
    old_updated_at = @budget.updated_at.to_i - 10
    @budget.touch

    patch budget_path(month_year: @budget.to_param), params: { budget: { budgeted_spending: 5000 }, last_updated_at: old_updated_at }

    assert_response :conflict
    assert_equal "Otra persona de tu familia modificó este presupuesto, recargá la pantalla.", @response.body
  end

  test "update succeeds if last_updated_at is equal to updated_at" do
    current_updated_at = @budget.updated_at.to_i

    patch budget_path(month_year: @budget.to_param), params: { budget: { budgeted_spending: 5500 }, last_updated_at: current_updated_at }

    assert_redirected_to budget_budget_categories_path(@budget)
    @budget.reload
    assert_equal 5500, @budget.budgeted_spending
  end

  test "copy_previous fails with 409 conflict if last_updated_at is older than updated_at" do
    old_updated_at = @budget.updated_at.to_i - 10
    @budget.touch

    post copy_previous_budget_path(month_year: @budget.to_param), params: { last_updated_at: old_updated_at }

    assert_response :conflict
    assert_equal "Otra persona de tu familia modificó este presupuesto, recargá la pantalla.", @response.body
  end
end
