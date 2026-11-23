require "test_helper"

module Dashboard
  class WidgetsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:family_admin)
      sign_in @user
    end

    test "GET available_to_spend renders turbo frame" do
      get available_to_spend_dashboard_widgets_url
      assert_response :success
      assert_select "turbo-frame#widget_available_to_spend"
    end

    test "GET recent_expenses renders turbo frame" do
      get recent_expenses_dashboard_widgets_url
      assert_response :success
      assert_select "turbo-frame#widget_recent_expenses"
    end

    test "GET budget_status renders turbo frame" do
      get budget_status_dashboard_widgets_url
      assert_response :success
      assert_select "turbo-frame#widget_budget_status"
    end

    test "GET sales_summary renders turbo frame" do
      get sales_summary_dashboard_widgets_url
      assert_response :success
      assert_select "turbo-frame#widget_sales_summary"
    end
  end
end
