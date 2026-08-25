require "test_helper"

class BudgetsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
    @budget = budgets(:one)
  end

  test "show renders budget page and fragment cached sidebar and donut" do
    get budget_path(@budget)
    assert_response :success
    assert_includes @response.body, "account-sidebar-tabs"
    assert_includes @response.body, "sidebar-active-account"
  end

  test "show renders current budget when month param is current" do
    get budget_path("current")
    assert_response :success
  end
end
