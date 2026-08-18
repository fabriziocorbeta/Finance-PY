require "test_helper"

class ReceivableTest < ActiveSupport::TestCase
  test "classification is asset" do
    assert_equal "asset", Receivable.classification
  end

  test "accepts nil due_day" do
    receivable = Receivable.new(due_day: nil)
    assert receivable.valid?
  end

  test "accepts due_day within 1..31" do
    receivable = Receivable.new(due_day: 15)
    assert receivable.valid?
  end

  test "rejects due_day outside 1..31" do
    receivable = Receivable.new(due_day: 32)
    assert_not receivable.valid?
    assert_includes receivable.errors[:due_day], "is not included in the list"
  end
end
