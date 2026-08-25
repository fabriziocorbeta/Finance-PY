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
end
