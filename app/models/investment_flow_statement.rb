class InvestmentFlowStatement
  include Monetizable

  attr_reader :family, :user

  def initialize(family, user: nil)
    @family = family
    @user = user
  end

  # Get contribution/withdrawal totals for a period
  def period_totals(period: Period.current_month)
    transaction_scope = family.transactions
      .visible
      .excluding_pending
      .where(entries: { date: period.date_range })
      .where(kind: %w[standard investment_contribution])
      .where(investment_activity_label: %w[Contribution Withdrawal])

    # Trades (e.g. a mutual fund sell/redemption) can also be labeled as a
    # Contribution/Withdrawal, so they must be included or they silently
    # disappear from this report even though the UI lets users label them.
    trade_scope = family.trades
      .where(entries: { date: period.date_range })
      .where(investment_activity_label: %w[Contribution Withdrawal])

    if user
      transaction_scope = transaction_scope.joins(entry: :account).merge(Account.included_in_finances_for(user))
      trade_scope = trade_scope.joins(entry: :account).merge(Account.included_in_finances_for(user))
    end

    contributions = transaction_scope.where(investment_activity_label: "Contribution").sum("entries.amount").abs +
      trade_scope.where(investment_activity_label: "Contribution").sum("entries.amount").abs

    withdrawals = transaction_scope.where(investment_activity_label: "Withdrawal").sum("entries.amount").abs +
      trade_scope.where(investment_activity_label: "Withdrawal").sum("entries.amount").abs

    PeriodTotals.new(
      contributions: Money.new(contributions, family.currency),
      withdrawals: Money.new(withdrawals, family.currency),
      net_flow: Money.new(contributions - withdrawals, family.currency)
    )
  end

  PeriodTotals = Data.define(:contributions, :withdrawals, :net_flow)
end
