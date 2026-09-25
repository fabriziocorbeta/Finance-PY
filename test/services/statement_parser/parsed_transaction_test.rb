require "test_helper"

module StatementParser
  class ParsedTransactionTest < ActiveSupport::TestCase
    def valid_attrs
      {
        date: "2026-05-01",
        description: "SUPERMERCADO STOCK",
        amount_cents: -15_000_000,
        currency: "PYG",
        transaction_type: :debit,
        balance_cents: 85_000_000
      }
    end

    test "valid? is true for a fully-formed row" do
      assert ParsedTransaction.new(valid_attrs).valid?
    end

    test "valid? is false when amount_cents is nil" do
      parsed = ParsedTransaction.new(valid_attrs.merge(amount_cents: nil))
      assert_not parsed.valid?
      # amount_cents itself still resolves to a safe default (0) rather
      # than raising, in case a caller reads it before checking valid? --
      # see #to_h and the review-screen display in show.html.erb.
      assert_equal 0, parsed.amount_cents
    end

    test "valid? is false when amount_cents is a garbage non-numeric string" do
      parsed = ParsedTransaction.new(valid_attrs.merge(amount_cents: "not-a-number"))
      assert_not parsed.valid?
    end

    test "valid? is true when amount_cents is zero and was explicitly present" do
      assert ParsedTransaction.new(valid_attrs.merge(amount_cents: 0)).valid?
    end

    test "valid? is false when description is blank" do
      assert_not ParsedTransaction.new(valid_attrs.merge(description: nil)).valid?
      assert_not ParsedTransaction.new(valid_attrs.merge(description: "   ")).valid?
    end

    test "valid? is false when date is missing" do
      assert_not ParsedTransaction.new(valid_attrs.merge(date: nil)).valid?
    end

    test "valid? is false when currency is not a real currency code" do
      assert_not ParsedTransaction.new(valid_attrs.merge(currency: "NOTACURRENCY")).valid?
    end
  end
end
