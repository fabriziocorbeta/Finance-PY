require "test_helper"

class Assistant::Function::GetTransactionsTest < ActiveSupport::TestCase
  include EntriesTestHelper

  setup do
    @family = families(:dylan_family)
    @restricted_user = users(:family_member) # shared: depository (full_control), credit_card (read_only)
    @private_account = accounts(:investment) # owned by family_admin, NOT shared with family_member

    @accessible_entry = create_transaction(
      account: accounts(:depository),
      name: "Accessible groceries",
      amount: 555.55
    )

    @private_entry = create_transaction(
      account: @private_account,
      name: "Private brokerage fee",
      amount: 777.77
    )

    @function = Assistant::Function::GetTransactions.new(@restricted_user)
  end

  test "excludes transactions from accounts the user cannot access" do
    result = @function.call("order" => "desc", "page" => 1)

    amounts = result[:transactions].map { |t| t[:amount] }
    account_names = result[:transactions].map { |t| t[:account] }

    assert_includes amounts, 555.55
    assert_not_includes amounts, 777.77
    assert_not_includes account_names, @private_account.name
  end

  test "totals exclude the inaccessible account's activity" do
    unrestricted_result = Assistant::Function::GetTransactions.new(users(:family_admin)).call("order" => "desc", "page" => 1)
    restricted_result = @function.call("order" => "desc", "page" => 1)

    assert restricted_result[:total_results] < unrestricted_result[:total_results]
  end

  test "account owner (family_admin) can still see the private account's transactions" do
    result = Assistant::Function::GetTransactions.new(users(:family_admin)).call("order" => "desc", "page" => 1)

    amounts = result[:transactions].map { |t| t[:amount] }
    assert_includes amounts, 777.77
  end
end
