# frozen_string_literal: true

module Reports
  class CashflowProjectionsBuilder
    ALLOWED_HORIZONS = [ 3, 6, 12 ].freeze
    DEFAULT_HORIZON = 6
    HISTORICAL_LOOKBACK_MONTHS = 12
    # Exclude internal fund movements, credit card payments, one-time items,
    # receivable collections, and investment contributions/withdrawals so
    # operating cashflow evolution and projections reflect real income and
    # operating expenses (standard + loan_payment).
    EXCLUDED_TRANSACTION_KINDS = (Transaction::BUDGET_EXCLUDED_KINDS + [ "investment_contribution" ]).uniq.freeze

    attr_reader :family, :user, :horizon_months, :reference_date

    def initialize(family:, user: nil, horizon_months: DEFAULT_HORIZON, reference_date: Date.current)
      @family = family
      @user = user
      @horizon_months = normalize_horizon(horizon_months)
      @reference_date = reference_date.to_date
    end

    def call
      hist = historical_series
      proj = projected_series(hist)

      {
        currency: family.currency,
        currency_symbol: Money::Currency.new(family.currency).symbol,
        horizon_months: horizon_months,
        historical_series: hist,
        projected_series: proj,
        drivers: projection_drivers(hist),
        summary: build_summary(hist, proj)
      }
    end

    private

      def normalize_horizon(val)
        parsed = val.to_i
        ALLOWED_HORIZONS.include?(parsed) ? parsed : DEFAULT_HORIZON
      end

      def income_statement
        @income_statement ||= IncomeStatement.new(family, user: user)
      end

      def operating_transactions_scope
        family.transactions
          .visible
          .excluding_pending
          .where.not(kind: EXCLUDED_TRANSACTION_KINDS)
      end

      def historical_series
        @historical_series ||= Rails.cache.fetch([
          "reports", "cashflow_historical_series", "v2",
          family.id, user&.id, reference_date, I18n.locale, family.entries_cache_version
        ]) do
          start_month = (reference_date.beginning_of_month - (HISTORICAL_LOOKBACK_MONTHS - 1).months).to_date
          end_month = reference_date.beginning_of_month.to_date
          monthly_totals = fetch_monthly_operating_totals(start_month..end_month.end_of_month)

          series = []
          current_month = start_month
          while current_month <= end_month
            month_key = current_month.strftime("%Y-%m")
            is_current = (current_month.year == reference_date.year && current_month.month == reference_date.month)
            totals = monthly_totals[month_key] || { income: 0.to_d, expenses: 0.to_d }

            inc = totals[:income].to_f
            exp = totals[:expenses].to_f
            net = inc - exp
            savings_rate = inc > 0 ? ((net / inc) * 100.0).round(1) : 0.0

            series << {
              month: month_key,
              month_label: I18n.l(current_month, format: "%b %Y"),
              date: current_month.strftime("%Y-%m-%d"),
              kind: "actual",
              is_current_month: is_current,
              income: inc.round(2),
              expenses: exp.round(2),
              net: net.round(2),
              savings_rate: savings_rate
            }

            current_month = current_month.next_month
          end

          series
        end
      end

      # Single-query 12-month aggregation (replaces 12 sequential monthly SQL queries on cold cache)
      def fetch_monthly_operating_totals(date_range)
        included_ids = user ? user.finance_accounts.pluck(:id) : nil
        return {} if included_ids&.empty?

        tx_sql = operating_transactions_scope.where(entries: { date: date_range }).to_sql
        tax_ids = family.tax_advantaged_account_ids
        tax_clause = tax_ids.present? ? "AND a.id NOT IN (:tax_advantaged_account_ids)" : ""
        inc_clause = included_ids ? "AND a.id IN (:included_account_ids)" : ""
        excluded_kinds_sql = Transaction::BUDGET_EXCLUDED_KINDS.map { |k| ActiveRecord::Base.connection.quote(k) }.join(", ")
        excluded_labels_sql = Transaction::BUDGET_EXCLUDED_LABELS.map { |l| ActiveRecord::Base.connection.quote(l) }.join(", ")

        sql = ActiveRecord::Base.sanitize_sql_array([
          <<~SQL,
            WITH classified AS (
              SELECT
                TO_CHAR(DATE_TRUNC('month', ae.date), 'YYYY-MM') AS month_key,
                c.id AS category_id,
                CASE WHEN at.kind IN ('investment_contribution', 'loan_payment') THEN 'expense'
                     WHEN ae.amount < 0 THEN 'income'
                     ELSE 'expense' END AS classification,
                ABS(SUM(
                  CASE WHEN at.kind IN ('investment_contribution', 'loan_payment')
                       THEN ABS(ae.amount * COALESCE(er.rate, 1))
                       ELSE ae.amount * COALESCE(er.rate, 1) END
                )) AS total
              FROM (#{tx_sql}) at
              JOIN entries ae ON ae.entryable_id = at.id AND ae.entryable_type = 'Transaction'
              JOIN accounts a ON a.id = ae.account_id
              LEFT JOIN categories c ON c.id = at.category_id
              LEFT JOIN exchange_rates er ON (
                er.date = ae.date AND
                er.from_currency = ae.currency AND
                er.to_currency = :target_currency
              )
              WHERE at.kind NOT IN (#{excluded_kinds_sql})
                AND (at.investment_activity_label IS NULL OR at.investment_activity_label NOT IN (#{excluded_labels_sql}))
                AND ae.excluded = false
                AND a.family_id = :family_id
                AND a.status IN ('draft', 'active')
                #{tax_clause}
                #{inc_clause}
              GROUP BY month_key, c.id,
                CASE WHEN at.kind IN ('investment_contribution', 'loan_payment') THEN 'expense'
                     WHEN ae.amount < 0 THEN 'income'
                     ELSE 'expense' END
            )
            SELECT
              month_key,
              COALESCE(SUM(CASE WHEN classification = 'income' THEN total ELSE 0 END), 0) AS income,
              COALESCE(SUM(CASE WHEN classification = 'expense' THEN total ELSE 0 END), 0) AS expenses
            FROM classified
            GROUP BY month_key
          SQL
          {
            target_currency: family.currency,
            family_id: family.id,
            tax_advantaged_account_ids: tax_ids.presence,
            included_account_ids: included_ids
          }.compact
        ])

        ActiveRecord::Base.connection.select_all(sql).each_with_object({}) do |row, hash|
          hash[row["month_key"]] = {
            income: row["income"].to_d,
            expenses: row["expenses"].to_d
          }
        end
      end

      def completed_historical_months(hist)
        completed = hist.reject { |m| m[:is_current_month] }
        # Filter to months that had any activity if there are active months, so empty leading months before onboarding don't skew averages
        first_active_idx = completed.index { |m| m[:income] > 0 || m[:expenses] > 0 }
        active_completed = first_active_idx ? completed[first_active_idx..] : []

        if active_completed.any?
          active_completed
        else
          # Fallback to current month if user only has data in the current month
          hist.select { |m| m[:income] > 0 || m[:expenses] > 0 }
        end
      end

      def historical_stats(hist)
        @historical_stats ||= begin
          months = completed_historical_months(hist)
          if months.empty?
            {
              avg_income: 0.0,
              avg_expenses: 0.0,
              weighted_income: 0.0,
              weighted_expenses: 0.0,
              income_slope: 0.0,
              expenses_slope: 0.0,
              income_stddev: 0.0,
              expenses_stddev: 0.0,
              sample_size: 0
            }
          else
            incomes = months.map { |m| m[:income] }
            expenses = months.map { |m| m[:expenses] }

            avg_inc = incomes.sum / incomes.size.to_f
            avg_exp = expenses.sum / expenses.size.to_f

            # Use outlier-resistant baseline (blend of median and winsorized weighted moving average)
            w_inc = robust_baseline(incomes)
            w_exp = robust_baseline(expenses)

            inc_slope = linear_slope(winsorize(incomes))
            exp_slope = linear_slope(winsorize(expenses))

            inc_std = standard_deviation(winsorize(incomes), w_inc)
            exp_std = standard_deviation(winsorize(expenses), w_exp)

            {
              avg_income: avg_inc.round(2),
              avg_expenses: avg_exp.round(2),
              weighted_income: w_inc.round(2),
              weighted_expenses: w_exp.round(2),
              income_slope: inc_slope.round(2),
              expenses_slope: exp_slope.round(2),
              income_stddev: inc_std.round(2),
              expenses_stddev: exp_std.round(2),
              sample_size: months.size
            }
          end
        end
      end

      def median(values)
        return 0.0 if values.empty?

        sorted = values.sort
        mid = sorted.size / 2
        if sorted.size.odd?
          sorted[mid].to_f
        else
          (sorted[mid - 1] + sorted[mid]) / 2.0
        end
      end

      # Caps extreme spikes at 1.6x the median (when median > 0) so a single
      # extraordinary month does not distort the 6-month projection.
      def winsorize(values)
        return [] if values.empty?
        return values if values.size < 3

        med = median(values)
        return values if med <= 0

        upper_cap = med * 1.6
        lower_cap = med * 0.4
        values.map { |v| v.clamp(lower_cap, upper_cap) }
      end

      def robust_baseline(values)
        return 0.0 if values.empty?

        cleaned = winsorize(values)
        med = median(cleaned)
        wma = weighted_moving_average(cleaned)

        # Blend 50% median + 50% winsorized weighted moving average
        (med * 0.5) + (wma * 0.5)
      end

      def weighted_moving_average(values)
        return 0.0 if values.empty?

        recent = values.last(6)
        weights = (1..recent.size).to_a
        weighted_sum = recent.zip(weights).sum { |val, w| val * w }
        weighted_sum / weights.sum.to_f
      end

      def linear_slope(values)
        n = values.size
        return 0.0 if n < 2

        recent = values.last(6)
        m = recent.size
        x_mean = (m - 1) / 2.0
        y_mean = recent.sum / m.to_f

        numerator = recent.each_with_index.sum { |y, x| (x - x_mean) * (y - y_mean) }
        denominator = (0...m).sum { |x| (x - x_mean) ** 2 }
        return 0.0 if denominator.zero?

        slope = numerator / denominator
        # Dampen slope to avoid runaway projections (cap at +/- 4% of mean per month)
        max_slope = y_mean.abs * 0.04
        slope.clamp(-max_slope, max_slope)
      end

      def standard_deviation(values, mean)
        return 0.0 if values.size < 2

        variance = values.sum { |v| (v - mean) ** 2 } / values.size.to_f
        Math.sqrt(variance)
      end

      def active_recurring_items
        @active_recurring_items ||= begin
          return { income: 0.0, expenses: 0.0, items_count: 0, income_items: [], expense_items: [] } if family.recurring_transactions_disabled?

          scope = family.recurring_transactions.active
          scope = scope.accessible_by(user) if user

          income_total = 0.0
          expense_total = 0.0
          income_items = []
          expense_items = []

          scope.includes(:merchant).each do |rt|
            raw_amount = rt.manual? && rt.expected_amount_avg.present? ? rt.expected_amount_avg : rt.amount
            next if raw_amount.nil? || raw_amount.zero?

            converted = convert_to_family_currency(raw_amount.abs, rt.currency)
            item_name = rt.merchant&.name.presence || rt.name

            if raw_amount.negative?
              income_total += converted
              income_items << { name: item_name, amount: converted.round(2), day: rt.expected_day_of_month }
            else
              expense_total += converted
              expense_items << { name: item_name, amount: converted.round(2), day: rt.expected_day_of_month }
            end
          end

          {
            income: income_total.round(2),
            expenses: expense_total.round(2),
            items_count: income_items.size + expense_items.size,
            income_items: income_items.sort_by { |i| -i[:amount] },
            expense_items: expense_items.sort_by { |i| -i[:amount] }
          }
        end
      end

      def active_budget_targets
        @active_budget_targets ||= begin
          # Look for the current month's or most recent initialized budget
          budget = family.budgets
            .where("start_date <= ?", reference_date.end_of_month)
            .where("budgeted_spending > 0 OR expected_income > 0")
            .order(start_date: :desc)
            .first

          if budget
            {
              has_budget: true,
              budgeted_spending: ensure_numeric(budget.budgeted_spending).round(2),
              expected_income: ensure_numeric(budget.expected_income).round(2),
              allocated_spending: ensure_numeric(budget.allocated_spending).round(2)
            }
          else
            {
              has_budget: false,
              budgeted_spending: 0.0,
              expected_income: 0.0,
              allocated_spending: 0.0
            }
          end
        end
      end

      def receivables_by_month
        @receivables_by_month ||= begin
          by_month = Hash.new { |h, k| h[k] = { total: 0.0, count: 0 } }

          receivable_accounts = family.accounts.where(accountable_type: "Receivable", status: [ "draft", "active" ])
          receivable_accounts = receivable_accounts.accessible_by(user) if user

          receivable_accounts.includes(:accountable, :entries).each do |acc|
            receivable = acc.accountable
            next unless receivable.is_a?(Receivable)

            receivable.installment_schedule.each do |inst|
              next unless inst[:status].in?([ :pending, :partial ])
              next unless inst[:due_date].present? && inst[:due_date] > reference_date

              remaining = (inst[:amount] - inst[:paid_amount]).to_f
              next if remaining <= 0

              converted = convert_to_family_currency(remaining, acc.currency)
              month_key = inst[:due_date].strftime("%Y-%m")
              by_month[month_key][:total] = (by_month[month_key][:total] + converted).round(2)
              by_month[month_key][:count] += 1
            end
          end

          by_month
        end
      end

      def projected_series(hist)
        stats = historical_stats(hist)
        recurring = active_recurring_items
        budget = active_budget_targets
        rec_schedule = receivables_by_month

        series = []
        first_future_month = reference_date.beginning_of_month.next_month.to_date

        (1..horizon_months).each do |step|
          target_month = (first_future_month + (step - 1).months).to_date
          month_key = target_month.strftime("%Y-%m")

          # 1. Trend-adjusted statistical baseline for this step
          # Dampen slope impact over longer horizons using sqrt(step)
          step_factor = Math.sqrt(step)
          trend_income = [ stats[:weighted_income] + (stats[:income_slope] * step_factor), 0.0 ].max
          trend_expenses = [ stats[:weighted_expenses] + (stats[:expenses_slope] * step_factor), 0.0 ].max

          # 2. Hybrid Income Projection:
          # Base is at least the active recurring income.
          # If historical trend is higher (variable income), blend trend with budget expected_income (if configured).
          base_income = if budget[:has_budget] && budget[:expected_income] > 0 && trend_income > 0
            (trend_income * 0.7) + (budget[:expected_income] * 0.3)
          elsif budget[:has_budget] && budget[:expected_income] > 0
            budget[:expected_income]
          else
            trend_income
          end

          # Ensure base income covers known recurring income, plus scheduled receivable installments for this month
          month_receivables = rec_schedule[month_key][:total]
          projected_income = [ base_income, recurring[:income] ].max + month_receivables

          # 3. Hybrid Expense Projection:
          # Fixed floor is recurring[:expenses].
          # Historical variable spending = max(trend_expenses - recurring[:expenses], 0)
          variable_expenses = [ trend_expenses - recurring[:expenses], 0.0 ].max
          statistical_expenses = recurring[:expenses] + variable_expenses

          budget_target_exp = budget[:budgeted_spending] > 0 ? budget[:budgeted_spending] : budget[:allocated_spending]
          projected_expenses = if budget[:has_budget] && budget_target_exp > 0 && statistical_expenses > 0
            # Blend 70% statistical reality + 30% budget target, never below fixed recurring expenses
            [ (statistical_expenses * 0.7) + (budget_target_exp * 0.3), recurring[:expenses] ].max
          elsif budget[:has_budget] && budget_target_exp > 0
            [ budget_target_exp, recurring[:expenses] ].max
          else
            statistical_expenses
          end

          projected_net = projected_income - projected_expenses
          savings_rate = projected_income > 0 ? ((projected_net / projected_income) * 100.0).round(1) : 0.0

          # 4. Scenarios (Optimistic / Conservative) based on historical volatility (or 15% fallback band)
          inc_band = stats[:income_stddev] > 0 ? [ stats[:income_stddev] * 0.75, projected_income * 0.35 ].min : (projected_income * 0.12)
          exp_band = stats[:expenses_stddev] > 0 ? [ stats[:expenses_stddev] * 0.75, projected_expenses * 0.35 ].min : (projected_expenses * 0.12)

          optimistic_income = (projected_income + inc_band).round(2)
          optimistic_expenses = [ projected_expenses - exp_band, recurring[:expenses] ].max.round(2)
          optimistic_net = (optimistic_income - optimistic_expenses).round(2)

          conservative_income = [ projected_income - inc_band, recurring[:income] + month_receivables ].max.round(2)
          conservative_expenses = (projected_expenses + exp_band).round(2)
          conservative_net = (conservative_income - conservative_expenses).round(2)

          series << {
            month: month_key,
            month_label: I18n.l(target_month, format: "%b %Y"),
            date: target_month.strftime("%Y-%m-%d"),
            kind: "projected",
            is_current_month: false,
            income: projected_income.round(2),
            expenses: projected_expenses.round(2),
            net: projected_net.round(2),
            savings_rate: savings_rate,
            recurring_income: recurring[:income],
            recurring_expenses: recurring[:expenses],
            receivables_income: month_receivables,
            optimistic: {
              income: optimistic_income,
              expenses: optimistic_expenses,
              net: optimistic_net
            },
            conservative: {
              income: conservative_income,
              expenses: conservative_expenses,
              net: conservative_net
            }
          }
        end

        series
      end

      def projection_drivers(hist)
        stats = historical_stats(hist)
        recurring = active_recurring_items
        budget = active_budget_targets

        future_receivables_total = receivables_by_month.sum do |month_key, data|
          target_date = Date.strptime(month_key, "%Y-%m")
          max_date = (reference_date.beginning_of_month + horizon_months.months).to_date
          target_date <= max_date ? data[:total] : 0.0
        end

        {
          recurring_income_monthly: recurring[:income],
          recurring_expenses_monthly: recurring[:expenses],
          recurring_items_count: recurring[:items_count],
          top_recurring_expenses: recurring[:expense_items].first(5),
          top_recurring_income: recurring[:income_items].first(5),
          historical_avg_income: stats[:weighted_income],
          historical_avg_expenses: stats[:weighted_expenses],
          income_trend_slope: stats[:income_slope],
          expenses_trend_slope: stats[:expenses_slope],
          sample_months: stats[:sample_size],
          has_budget: budget[:has_budget],
          budgeted_spending: budget[:budgeted_spending] > 0 ? budget[:budgeted_spending] : budget[:allocated_spending],
          expected_income: budget[:expected_income],
          scheduled_receivables_total: future_receivables_total.round(2)
        }
      end

      def build_summary(hist, proj)
        total_proj_income = proj.sum { |m| m[:income] }.round(2)
        total_proj_expenses = proj.sum { |m| m[:expenses] }.round(2)
        total_proj_net = (total_proj_income - total_proj_expenses).round(2)

        avg_proj_income = proj.any? ? (total_proj_income / proj.size.to_f).round(2) : 0.0
        avg_proj_expenses = proj.any? ? (total_proj_expenses / proj.size.to_f).round(2) : 0.0
        avg_proj_net = proj.any? ? (total_proj_net / proj.size.to_f).round(2) : 0.0
        proj_savings_rate = total_proj_income > 0 ? ((total_proj_net / total_proj_income) * 100.0).round(1) : 0.0

        optimistic_net_total = proj.sum { |m| m.dig(:optimistic, :net) || 0.0 }.round(2)
        conservative_net_total = proj.sum { |m| m.dig(:conservative, :net) || 0.0 }.round(2)

        stats = historical_stats(hist)
        income_vs_hist_pct = stats[:weighted_income] > 0 ? (((avg_proj_income - stats[:weighted_income]) / stats[:weighted_income]) * 100.0).round(1) : 0.0
        expenses_vs_hist_pct = stats[:weighted_expenses] > 0 ? (((avg_proj_expenses - stats[:weighted_expenses]) / stats[:weighted_expenses]) * 100.0).round(1) : 0.0

        {
          total_projected_income: total_proj_income,
          total_projected_expenses: total_proj_expenses,
          total_projected_net: total_proj_net,
          avg_monthly_projected_income: avg_proj_income,
          avg_monthly_projected_expenses: avg_proj_expenses,
          avg_monthly_projected_net: avg_proj_net,
          projected_savings_rate: proj_savings_rate,
          optimistic_total_net: optimistic_net_total,
          conservative_total_net: conservative_net_total,
          income_vs_historical_pct: income_vs_hist_pct,
          expenses_vs_historical_pct: expenses_vs_hist_pct
        }
      end

      def ensure_numeric(value)
        return 0.0 if value.nil?
        return value.amount.to_f if value.is_a?(Money)

        value.to_f
      end

      def convert_to_family_currency(amount, from_currency)
        return amount.to_f if from_currency.blank? || from_currency.to_s.casecmp?(family.currency.to_s)

        Money.new(amount, from_currency).exchange_to(family.currency).amount.to_f
      rescue Money::ConversionError
        amount.to_f
      end
  end
end
