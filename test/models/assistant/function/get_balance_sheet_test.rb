require "test_helper"

class Assistant::Function::GetBalanceSheetTest < ActiveSupport::TestCase
  FakeSection = Struct.new(:total, :total_money)
  FakeBalanceSheet = Struct.new(:assets, :liabilities, :net_worth_money)

  test "insights_data guards zero assets without producing Infinity%" do
    user = users(:family_admin)
    fn = Assistant::Function::GetBalanceSheet.new(user)

    zero_money = Money.new(0, "USD")
    fake_sheet = FakeBalanceSheet.new(
      FakeSection.new(0, zero_money),
      FakeSection.new(500, Money.new(500, "USD")),
      Money.new(-500, "USD")
    )

    user.family.stub(:balance_sheet, fake_sheet) do
      insights = fn.send(:insights_data)
      assert_equal "0%", insights[:debt_to_asset_ratio]
    end
  end
end
