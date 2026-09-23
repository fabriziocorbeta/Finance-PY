require "test_helper"

class Assistant::Function::GetIncomeStatementTest < ActiveSupport::TestCase
  include EntriesTestHelper

  # A date far outside fixture data's range so our test entries are the only
  # activity in the aggregation period (avoids brittle assertions against
  # other fixture transactions).
  TEST_DATE = Date.new(2030, 6, 15)

  setup do
    @family = families(:dylan_family)
    @restricted_user = users(:family_member) # shared: depository (full_control), credit_card (read_only)
    @private_account = accounts(:investment) # owned by family_admin, NOT shared with family_member

    create_transaction(
      account: @private_account,
      name: "Private June expense",
      amount: 500,
      date: TEST_DATE
    )

    create_transaction(
      account: accounts(:depository),
      name: "Accessible June expense",
      amount: 300,
      date: TEST_DATE
    )

    @function = Assistant::Function::GetIncomeStatement.new(@restricted_user)
  end

  test "expense totals exclude spend from accounts the user cannot access" do
    result = @function.call(
      "start_date" => TEST_DATE.beginning_of_month.to_s,
      "end_date" => TEST_DATE.end_of_month.to_s
    )

    assert_equal Money.new(300, @family.currency).format, result[:expense][:total]
  end

  test "account owner (family_admin) sees the full expense total" do
    result = Assistant::Function::GetIncomeStatement.new(users(:family_admin)).call(
      "start_date" => TEST_DATE.beginning_of_month.to_s,
      "end_date" => TEST_DATE.end_of_month.to_s
    )

    assert_equal Money.new(800, @family.currency).format, result[:expense][:total]
  end
end
