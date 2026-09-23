# frozen_string_literal: true

require "test_helper"

module Reports
  class TransactionsCsvBuilderTest < ActiveSupport::TestCase
    include EntriesTestHelper

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

    test "prefixes CSV formula-injection payloads in category names with an apostrophe" do
      malicious_category = @family.categories.create!(name: "=1+1", color: "#123456")

      create_transaction(
        account: accounts(:depository),
        amount: 50,
        date: Date.current,
        category: malicious_category
      )

      builder = Reports::TransactionsCsvBuilder.new(
        family: @family,
        user: @user,
        period_type: "monthly"
      )

      csv_output = builder.generate_csv

      assert_includes csv_output, "'=1+1"
      refute_match(/(?<!')=1\+1/, csv_output)
    end
  end
end
