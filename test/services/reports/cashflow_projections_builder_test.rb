# frozen_string_literal: true

require "test_helper"

module Reports
  class CashflowProjectionsBuilderTest < ActiveSupport::TestCase
    include EntriesTestHelper

    setup do
      @family = families(:dylan_family)
      @user = users(:family_admin)
      @account = accounts(:depository)
    end

    test "returns default 6-month horizon and 12-month historical series" do
      result = Reports::CashflowProjectionsBuilder.new(
        family: @family,
        user: @user
      ).call

      assert_equal 6, result[:horizon_months]
      assert_equal @family.currency, result[:currency]
      assert_equal 12, result[:historical_series].size
      assert_equal 6, result[:projected_series].size

      result[:historical_series].each do |item|
        assert_equal "actual", item[:kind]
        assert item.key?(:income)
        assert item.key?(:expenses)
        assert item.key?(:net)
      end

      result[:projected_series].each do |item|
        assert_equal "projected", item[:kind]
        assert item.key?(:income)
        assert item.key?(:expenses)
        assert item.key?(:net)
        assert item.key?(:optimistic)
        assert item.key?(:conservative)
      end
    end

    test "supports 3 and 12 month horizons and falls back to 6 on invalid input" do
      res_3 = Reports::CashflowProjectionsBuilder.new(family: @family, user: @user, horizon_months: 3).call
      assert_equal 3, res_3[:horizon_months]
      assert_equal 3, res_3[:projected_series].size

      res_12 = Reports::CashflowProjectionsBuilder.new(family: @family, user: @user, horizon_months: "12").call
      assert_equal 12, res_12[:horizon_months]
      assert_equal 12, res_12[:projected_series].size

      res_invalid = Reports::CashflowProjectionsBuilder.new(family: @family, user: @user, horizon_months: 99).call
      assert_equal 6, res_invalid[:horizon_months]
      assert_equal 6, res_invalid[:projected_series].size
    end

    test "incorporates active recurring transactions into projected floor" do
      # Clear existing recurring transactions for clean assertion
      @family.recurring_transactions.destroy_all

      # Add active recurring income (-3000) and recurring expense (+1200)
      @family.recurring_transactions.create!(
        account: @account,
        name: "Monthly Salary",
        amount: -3000.0,
        currency: @family.currency,
        expected_day_of_month: 1,
        last_occurrence_date: 1.month.ago.to_date,
        next_expected_date: Date.current.next_month.beginning_of_month,
        status: "active",
        occurrence_count: 3
      )

      @family.recurring_transactions.create!(
        account: @account,
        name: "Apartment Rent",
        amount: 1200.0,
        currency: @family.currency,
        expected_day_of_month: 5,
        last_occurrence_date: 1.month.ago.to_date,
        next_expected_date: Date.current.next_month.beginning_of_month + 4.days,
        status: "active",
        occurrence_count: 3
      )

      result = Reports::CashflowProjectionsBuilder.new(
        family: @family,
        user: @user,
        horizon_months: 3
      ).call

      drivers = result[:drivers]
      assert_equal 3000.0, drivers[:recurring_income_monthly]
      assert_equal 1200.0, drivers[:recurring_expenses_monthly]
      assert_equal 2, drivers[:recurring_items_count]

      first_proj = result[:projected_series].first
      assert_operator first_proj[:income], :>=, 3000.0
      assert_operator first_proj[:expenses], :>=, 1200.0
    end

    test "includes pending receivable installments in projected months" do
      # The family fixtures already carry receivables with pending installments,
      # so measure what this test's receivable adds on top of that baseline
      # instead of asserting absolute totals.
      baseline = Reports::CashflowProjectionsBuilder.new(
        family: @family,
        user: @user,
        horizon_months: 6
      ).call
      baseline_total = baseline[:drivers][:scheduled_receivables_total]
      baseline_first_month = baseline[:projected_series].first[:receivables_income]

      receivable = Receivable.new(
        family: @family,
        total_amount: 600.0,
        installment_count: 3,
        first_due_date: Date.current.next_month.beginning_of_month + 10.days
      )
      @family.accounts.create!(
        name: "Client Invoice",
        balance: 600.0,
        currency: @family.currency,
        accountable: receivable,
        status: "active"
      )

      result = Reports::CashflowProjectionsBuilder.new(
        family: @family,
        user: @user,
        horizon_months: 6
      ).call

      assert_in_delta 600.0, result[:drivers][:scheduled_receivables_total] - baseline_total, 0.01
      first_proj = result[:projected_series].first
      assert_in_delta 200.0, first_proj[:receivables_income] - baseline_first_month, 0.01
    end

    test "excludes investment_contribution transfers from operating expense evolution and projections" do
      create_transaction(
        account: @account,
        name: "Transfer to Brokerage",
        amount: 10_000_000,
        date: 1.month.ago.to_date,
        kind: "investment_contribution"
      )

      result = Reports::CashflowProjectionsBuilder.new(
        family: @family,
        user: @user,
        horizon_months: 3
      ).call

      last_closed_month = 1.month.ago.strftime("%Y-%m")
      hist_month = result[:historical_series].find { |m| m[:month] == last_closed_month }
      assert_not_nil hist_month
      assert_operator hist_month[:expenses], :<, 10_000_000
    end
  end
end
