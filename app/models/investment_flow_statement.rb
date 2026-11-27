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
    if account
      by_account = period_totals_by_account(period: period, account_ids: [ account.id ])
      return by_account[account.id] || zero_period_totals
    end

    cache_key = [
      "investment_flow_statement", "period_totals", "v1",
      family.id, user&.id, period.start_date, period.end_date, family.entries_cache_version
    ]
    raw = Rails.cache.fetch(cache_key) do
      compute_combined_totals(period: period)
    end

    build_period_totals(raw[:contributions], raw[:withdrawals])
  end

  # Batch-computes PeriodTotals grouped by account_id in a single cached query
  # so callers iterating over investment_accounts (e.g. unrealized_gains_trend)
  # don't trigger 4 * N SQL queries.
  def period_totals_by_account(period: Period.current_month, account_ids: nil)
    ids_key = account_ids ? Digest::MD5.hexdigest(account_ids.map(&:to_s).sort.join(",")) : "all"
    cache_key = [
      "investment_flow_statement", "by_account", "v1",
      family.id, user&.id, ids_key, period.start_date, period.end_date, family.entries_cache_version
    ]
    raw_by_account = Rails.cache.fetch(cache_key) do
      compute_totals_grouped_by_account(period: period, account_ids: account_ids)
    end

    raw_by_account.transform_values do |vals|
      build_period_totals(vals[:contributions], vals[:withdrawals])
    end
  end

  PeriodTotals = Data.define(:contributions, :withdrawals, :net_flow)

  private
    def zero_period_totals
      build_period_totals(0.to_d, 0.to_d)
    end

    def build_period_totals(contributions, withdrawals)
      c = contributions.to_d
      w = withdrawals.to_d
      PeriodTotals.new(
        contributions: Money.new(c, family.currency),
        withdrawals: Money.new(w, family.currency),
        net_flow: Money.new(c - w, family.currency)
      )
    end

    def build_scopes(period:, account_ids: nil)
      transaction_scope = family.transactions
        .visible
        .excluding_pending
        .where(entries: { date: period.date_range })
        .where(kind: %w[standard investment_contribution])
        .where(investment_activity_label: %w[Contribution Withdrawal])

      trade_scope = family.trades
        .where(entries: { date: period.date_range })
        .where(investment_activity_label: %w[Contribution Withdrawal])

      if account_ids
        transaction_scope = transaction_scope.where(entries: { account_id: account_ids })
        trade_scope = trade_scope.where(entries: { account_id: account_ids })
      end

      if user
        transaction_scope = transaction_scope.joins(entry: :account).merge(Account.included_in_finances_for(user))
        trade_scope = trade_scope.joins(entry: :account).merge(Account.included_in_finances_for(user))
      end

      [ transaction_scope, trade_scope ]
    end

    def combined_entries_union_sql(transaction_scope, trade_scope)
      tx_sql = transaction_scope.select(
        "entries.account_id AS account_id, entries.amount AS amount, entries.currency AS currency, " \
        "entries.date AS date, transactions.investment_activity_label AS activity_label"
      ).to_sql

      tr_sql = trade_scope.select(
        "entries.account_id AS account_id, entries.amount AS amount, entries.currency AS currency, " \
        "entries.date AS date, trades.investment_activity_label AS activity_label"
      ).to_sql

      "(#{tx_sql}) UNION ALL (#{tr_sql})"
    end

    def fx_rate_expr_sql
      <<~SQL.squish
        COALESCE(
          (SELECT er.rate FROM exchange_rates er
           WHERE er.from_currency = e.currency AND er.to_currency = :target_currency AND er.date <= e.date
           ORDER BY er.date DESC LIMIT 1),
          (SELECT er.rate FROM exchange_rates er
           WHERE er.from_currency = e.currency AND er.to_currency = :target_currency AND er.date > e.date
           ORDER BY er.date ASC LIMIT 1),
          1
        )
      SQL
    end

    def compute_combined_totals(period:)
      transaction_scope, trade_scope = build_scopes(period: period)
      union_sql = combined_entries_union_sql(transaction_scope, trade_scope)

      sql = ActiveRecord::Base.sanitize_sql_array([
        <<~SQL,
          SELECT
            COALESCE(SUM(CASE WHEN e.activity_label = 'Contribution' THEN ABS(e.amount) * #{fx_rate_expr_sql} ELSE 0 END), 0) AS contributions,
            COALESCE(SUM(CASE WHEN e.activity_label = 'Withdrawal' THEN ABS(e.amount) * #{fx_rate_expr_sql} ELSE 0 END), 0) AS withdrawals
          FROM (#{union_sql}) e
        SQL
        { target_currency: family.currency }
      ])

      row = ActiveRecord::Base.connection.select_one(sql) || {}
      {
        contributions: row["contributions"].to_d,
        withdrawals: row["withdrawals"].to_d
      }
    end

    def compute_totals_grouped_by_account(period:, account_ids: nil)
      return {} if account_ids&.empty?

      transaction_scope, trade_scope = build_scopes(period: period, account_ids: account_ids)
      union_sql = combined_entries_union_sql(transaction_scope, trade_scope)

      sql = ActiveRecord::Base.sanitize_sql_array([
        <<~SQL,
          SELECT
            e.account_id AS account_id,
            COALESCE(SUM(CASE WHEN e.activity_label = 'Contribution' THEN ABS(e.amount) * #{fx_rate_expr_sql} ELSE 0 END), 0) AS contributions,
            COALESCE(SUM(CASE WHEN e.activity_label = 'Withdrawal' THEN ABS(e.amount) * #{fx_rate_expr_sql} ELSE 0 END), 0) AS withdrawals
          FROM (#{union_sql}) e
          GROUP BY e.account_id
        SQL
        { target_currency: family.currency }
      ])

      ActiveRecord::Base.connection.select_all(sql).each_with_object({}) do |row, hash|
        hash[row["account_id"]] = {
          contributions: row["contributions"].to_d,
          withdrawals: row["withdrawals"].to_d
        }
      end
    end
end
