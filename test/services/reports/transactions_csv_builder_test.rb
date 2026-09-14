# frozen_string_literal: true

require "test_helper"

module Reports
  class TransactionsCsvBuilderTest < ActiveSupport::TestCase
    setup do
      @family = families(:dylan_family)
      @user = users(:family_admin)
    end

    test "generates valid CSV filename and content" do
      builder = Reports::TransactionsCsvBuilder.new(
        family: @family,
        user: @user,
        period_type: "monthly",
        start_date: "2025-01-01",
        end_date: "2025-01-31"
      )

      assert_equal "transactions_breakdown_20250101_to_20250131.csv", builder.filename

      csv_output = builder.generate_csv
      assert_not_nil csv_output
      assert_includes csv_output, "Category"
      assert_includes csv_output, "Total"
    end

    test "handles custom period types and date parsing" do
      builder = Reports::TransactionsCsvBuilder.new(
        family: @family,
        user: @user,
        period_type: "custom",
        start_date: "2025-02-15",
        end_date: "2025-02-01"
      )

      assert_equal Date.parse("2025-02-01"), builder.start_date
      assert_equal Date.parse("2025-02-15"), builder.end_date
      assert_equal "transactions_breakdown_20250201_to_20250215.csv", builder.filename
    end
  end
end
