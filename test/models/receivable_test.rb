require 'test_helper'

class ReceivableTest < ActiveSupport::TestCase
  test "classification is asset" do
    assert_equal "asset", Receivable.classification
  end

  test "accepts nil due_day" do
    receivable = Receivable.new(family: families(:dylan_family), due_day: nil)
    assert receivable.valid?
  end

  test "accepts due_day within 1..31" do
    receivable = Receivable.new(family: families(:dylan_family), due_day: 15)
    assert receivable.valid?
  end

  test "rejects due_day outside 1..31" do
    receivable = Receivable.new(due_day: 32)
    assert_not receivable.valid?
    assert_includes receivable.errors[:due_day], "is not included in the list"
  end

  test "calculates installment_schedule correctly with partial and full payments" do
    family = families(:dylan_family)
    account = Account.create!(
      family: family,
      name: "Test Receivable",
      balance: 1000,
      currency: "USD",
      accountable_type: "Receivable",
      accountable: Receivable.new(
        family: family,
        total_amount: 1000,
        installment_count: 4,
        due_day: 15
      )
    )

    receivable = account.accountable

    # Schedule: 4 installments of 250 each.
    schedule = receivable.installment_schedule
    assert_equal 4, schedule.length
    assert_equal 250, schedule[0][:amount]
    assert_equal :pending, schedule[0][:status]

    # Add a payment of 300 (covers 1st installment + 50 of 2nd)
    Entry.create!(
      account: account,
      amount: 300,
      date: Date.current - 1.day,
      currency: "USD",
      name: "Payment"
    )

    schedule = receivable.installment_schedule

    assert_equal :paid, schedule[0][:status]
    assert_equal 250, schedule[0][:paid_amount]

    assert_equal :partial, schedule[1][:status]
    assert_equal 50, schedule[1][:paid_amount]

    assert_equal :pending, schedule[2][:status]
    assert_equal 0, schedule[2][:paid_amount]
  end
end
