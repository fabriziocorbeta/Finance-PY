class InvestmentFlowStatement
  include Monetizable

  attr_reader :family, :user

  def initialize(family, user: nil)
    @family = family
    @user = user
  end

  # Get contribution/withdrawal totals for a period. Pass `account` to scope
  # the totals to a single investment account instead of the whole family.
  def period_totals(period: Period.current_month, account: nil)
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

    if account
      transaction_scope = transaction_scope.where(entries: { account_id: account.id })
      trade_scope = trade_scope.where(entries: { account_id: account.id })
    end

    if user
      transaction_scope = transaction_scope.joins(entry: :account).merge(Account.included_in_finances_for(user))
      trade_scope = trade_scope.joins(entry: :account).merge(Account.included_in_finances_for(user))
    end

    contributions = fx_converted_sum(transaction_scope.where(investment_activity_label: "Contribution")) +
      fx_converted_sum(trade_scope.where(investment_activity_label: "Contribution"))

    withdrawals = fx_converted_sum(transaction_scope.where(investment_activity_label: "Withdrawal")) +
      fx_converted_sum(trade_scope.where(investment_activity_label: "Withdrawal"))

    PeriodTotals.new(
      contributions: Money.new(contributions, family.currency),
      withdrawals: Money.new(withdrawals, family.currency),
      net_flow: Money.new(contributions - withdrawals, family.currency)
    )
  end

  PeriodTotals = Data.define(:contributions, :withdrawals, :net_flow)

  private
    # Sums entries.amount converted to family currency, using the nearest
    # available exchange rate for each entry's own currency and date --
    # mirroring the LEFT JOIN LATERAL pattern already used for this in
    # Balance::ChartSeriesBuilder and InvestmentStatement::Totals.
    #
    # This used to be a plain `scope.sum("entries.amount")`, with no FX
    # conversion at all: a foreign-currency account's contributions or
    # withdrawals were summed using their raw, un-converted amount as if it
    # were already in family currency.
    def fx_converted_sum(scope)
      entries_sql = scope.select("entries.amount AS amount, entries.currency AS currency, entries.date AS date").to_sql

      sql = ActiveRecord::Base.sanitize_sql_array([
        <<~SQL,
          SELECT COALESCE(SUM(ABS(e.amount) * COALESCE(
            (SELECT er.rate FROM exchange_rates er
             WHERE er.from_currency = e.currency AND er.to_currency = :target_currency AND er.date <= e.date
             ORDER BY er.date DESC LIMIT 1),
            (SELECT er.rate FROM exchange_rates er
             WHERE er.from_currency = e.currency AND er.to_currency = :target_currency AND er.date > e.date
             ORDER BY er.date ASC LIMIT 1),
            1
          )), 0) AS total
          FROM (#{entries_sql}) e
        SQL
        { target_currency: family.currency }
      ])

      ActiveRecord::Base.connection.select_value(sql).to_d
    end
end
