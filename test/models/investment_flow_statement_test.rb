require "test_helper"

class InvestmentFlowStatementTest < ActiveSupport::TestCase
  setup do
    @family = families(:empty)
    @depository = @family.accounts.create! name: "Checking", currency: @family.currency, balance: 5000, accountable: Depository.new
    @investment = @family.accounts.create! name: "Brokerage", currency: @family.currency, balance: 10000, accountable: Investment.new
  end

  test "a transfer out of an investment account is counted as a withdrawal" do
    Transfer::Creator.new(
      family: @family,
      source_account_id: @investment.id,
      destination_account_id: @depository.id,
      date: Date.current,
      amount: 500
    ).create

    totals = InvestmentFlowStatement.new(@family).period_totals(period: Period.current_month)

    assert_equal Money.new(500, @family.currency), totals.withdrawals
    assert_equal Money.new(0, @family.currency), totals.contributions
  end

  test "a transfer into an investment account is counted as a contribution" do
    Transfer::Creator.new(
      family: @family,
      source_account_id: @depository.id,
      destination_account_id: @investment.id,
      date: Date.current,
      amount: 500
    ).create

    totals = InvestmentFlowStatement.new(@family).period_totals(period: Period.current_month)

    assert_equal Money.new(500, @family.currency), totals.contributions
    assert_equal Money.new(0, @family.currency), totals.withdrawals
  end

  # Regression test: the manual "quick edit" activity-label badge
  # (ActivityLabelQuickEditController) PATCHes only investment_activity_label,
  # never kind. Before Transaction's kind/investment_activity_label sync
  # callback existed, this silently created a transaction that was real money
  # but invisible to this report -- the exact bug class that already hit
  # production once via Transfer::Creator's withdrawal side.
  test "manually relabeling a transaction as Withdrawal without touching kind still appears in period_totals" do
    transaction = Transaction.create!(
      family: @family,
      kind: "funds_movement",
      entry: @investment.entries.build(
        amount: 300, currency: @family.currency, date: Date.current, name: "Transfer to Checking"
      )
    )

    transaction.update!(investment_activity_label: "Withdrawal")

    totals = InvestmentFlowStatement.new(@family).period_totals(period: Period.current_month)

    assert_equal Money.new(300, @family.currency), totals.withdrawals
  end

  # Regression test: period_totals summed entries.amount directly with no
  # FX conversion at all, so a foreign-currency account's contributions and
  # withdrawals were reported using the raw, un-converted number as if it
  # were already in family currency.
  test "a withdrawal from a foreign-currency investment account is converted to family currency" do
    eur_investment = @family.accounts.create! name: "EUR Brokerage", currency: "EUR", balance: 10000, accountable: Investment.new
    ExchangeRate.create!(from_currency: "EUR", to_currency: @family.currency, date: Date.current, rate: 1.1)

    transaction = Transaction.create!(
      family: @family,
      kind: "funds_movement",
      entry: eur_investment.entries.build(
        amount: 300, currency: "EUR", date: Date.current, name: "Withdrawal"
      )
    )
    transaction.update!(investment_activity_label: "Withdrawal")

    totals = InvestmentFlowStatement.new(@family).period_totals(period: Period.current_month)

    assert_equal Money.new(330, @family.currency), totals.withdrawals
  end
end
