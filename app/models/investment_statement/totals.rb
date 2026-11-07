class InvestmentStatement::Totals
  def initialize(family, trades_scope:)
    @family = family
    @trades_scope = trades_scope
  end

  def call
    result = ActiveRecord::Base.connection.select_one(query_sql)

    {
      contributions: result["contributions"]&.to_d || 0,
      withdrawals: result["withdrawals"]&.to_d || 0,
      dividends: result["dividends"]&.to_d || 0,
      interest: result["interest"]&.to_d || 0,
      trades_count: result["trades_count"]&.to_i || 0
    }
  end

  private
    def query_sql
      ActiveRecord::Base.sanitize_sql_array([
        aggregation_sql,
        sql_params
      ])
    end

    # Aggregate trades by direction (buy vs sell)
    # Buys (qty > 0) = contributions (cash going out to buy securities)
    # Sells (qty < 0) = withdrawals (cash coming in from selling securities)
    #
    # Interest and dividend credits are a third kind and are split out by
    # investment_activity_label rather than by quantity. They carry qty = 0 --
    # no security changes hands, the account is simply credited -- so the
    # qty > 0 / qty < 0 split above sees them as neither a buy nor a sell and
    # they used to vanish entirely: `interest` was hardcoded to 0 here with a
    # comment claiming interest arrives as a transaction. That is not true for
    # interest entered by hand on a fund or savings account, which is a Trade,
    # and it made a real PYG 105,964 of credited interest invisible to every
    # return figure in the app.
    #
    # They are excluded from contributions/withdrawals on purpose: interest is
    # a return ON the capital, not new capital put in, so counting it as a
    # contribution would inflate the denominator and understate the yield.
    def aggregation_sql
      <<~SQL
        SELECT
          COALESCE(SUM(CASE WHEN t.qty > 0 AND #{not_income_sql} THEN ABS(ae.amount * COALESCE(er.rate, 1)) ELSE 0 END), 0) as contributions,
          COALESCE(SUM(CASE WHEN t.qty < 0 AND #{not_income_sql} THEN ABS(ae.amount * COALESCE(er.rate, 1)) ELSE 0 END), 0) as withdrawals,
          COALESCE(SUM(CASE WHEN t.investment_activity_label = 'Interest' THEN ABS(ae.amount * COALESCE(er.rate, 1)) ELSE 0 END), 0) as interest,
          COALESCE(SUM(CASE WHEN t.investment_activity_label = 'Dividend' THEN ABS(ae.amount * COALESCE(er.rate, 1)) ELSE 0 END), 0) as dividends,
          COUNT(t.id) as trades_count
        FROM (#{@trades_scope.to_sql}) t
        JOIN entries ae ON ae.entryable_id = t.id AND ae.entryable_type = 'Trade'
        JOIN accounts a ON a.id = ae.account_id
        #{nearest_rate_join_sql}
        WHERE a.family_id = :family_id
          AND a.status IN ('draft', 'active')
          AND ae.excluded = false
      SQL
    end

    # Income credits (interest/dividends) must not also land in the buy/sell
    # buckets. NULL-safe because every pre-existing trade has a NULL label.
    def not_income_sql
      "COALESCE(t.investment_activity_label, '') NOT IN ('Interest', 'Dividend')"
    end

    # An exact-date join silently fell back to a 1:1 rate (via the outer
    # COALESCE(er.rate, 1) above) whenever a trade landed on a day with no
    # stored rate for its currency -- e.g. a weekend, or any day the FX
    # importer hadn't backfilled yet -- with no indication that had
    # happened. Mirrors the nearest-rate LATERAL join already used for the
    # same problem in Balance::ChartSeriesBuilder: nearest rate on or before
    # the trade's date, falling back to the nearest one after it.
    def nearest_rate_join_sql
      <<~SQL
        LEFT JOIN LATERAL (
          SELECT COALESCE(
            (SELECT er.rate
             FROM exchange_rates er
             WHERE er.from_currency = ae.currency
               AND er.to_currency = :target_currency
               AND er.date <= ae.date
             ORDER BY er.date DESC
             LIMIT 1),
            (SELECT er.rate
             FROM exchange_rates er
             WHERE er.from_currency = ae.currency
               AND er.to_currency = :target_currency
               AND er.date > ae.date
             ORDER BY er.date ASC
             LIMIT 1)
          ) AS rate
        ) er ON TRUE
      SQL
    end

    def sql_params
      {
        family_id: @family.id,
        target_currency: @family.currency
      }
    end
end
