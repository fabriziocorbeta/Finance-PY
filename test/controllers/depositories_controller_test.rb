require "test_helper"

class DepositoriesControllerTest < ActionDispatch::IntegrationTest
  include AccountableResourceInterfaceTest

  setup do
    sign_in @user = users(:family_admin)
    @account = accounts(:depository)
  end

  test "new form defaults opening_balance_date to today" do
    get new_depository_url

    assert_response :success
    assert_select "input[name='account[opening_balance_date]'][value='#{Time.zone.today}']"
  end

  test "create defaults opening_balance_date to today when omitted" do
    assert_difference "Account.count", 1 do
      post depositories_url, params: {
        account: {
          name: "Takenos",
          balance: 100,
          currency: "USD"
        }
      }
    end

    account = Account.order(:created_at).last
    assert_equal Time.zone.today, account.opening_balance_date
  end
end
