# frozen_string_literal: true

module Reports
  class SummaryBuilder
    ALLOWED_PERIOD_TYPES = %w[monthly quarterly ytd last_6_months custom].freeze

    attr_reader :family, :user, :period_type, :start_date, :end_date, :period, :previous_period

    def initialize(family:, user: nil, period_type: "monthly", start_date: nil, end_date: nil)
      @family = family
      @user = user
      @period_type = (period_type.presence_in(ALLOWED_PERIOD_TYPES) || "monthly").to_sym
      parse_dates(start_date, end_date)

      # Build periods
      @period = Period.custom(start_date: @start_date, end_date: @end_date)
      @previous_period = build_previous_period
    end

    def build_all
      {
        period: {
          start_date: start_date.to_s,
          end_date: end_date.to_s,
          type: period_type.to_s
        },
        summary: build_summary_metrics,
        trends: build_trends_data,
        net_worth: build_net_worth_metrics,
        transactions_breakdown: build_transactions_breakdown
      }
    end

    private

      def parse_dates(start_date_param, end_date_param)
        s_date = parse_date(start_date_param) || default_start_date
        e_date = parse_date(end_date_param) || default_end_date

        if s_date > e_date
          s_date, e_date = e_date, s_date
        end

        @start_date = s_date
        @end_date = e_date
      end

      def parse_date(val)
        return val if val.is_a?(Date)
        return nil if val.blank?

        Date.parse(val.to_s)
      rescue Date::Error
        nil
      end

      def default_start_date
        case period_type
        when :monthly
          Date.current.beginning_of_month.to_date
        when :quarterly
          Date.current.beginning_of_quarter.to_date
        when :ytd
          Date.current.beginning_of_year.to_date
        when :last_6_months
          6.months.ago.beginning_of_month.to_date
        when :custom
          1.month.ago.to_date
        else
          Date.current.beginning_of_month.to_date
        end
      end

      def default_end_date
        case period_type
        when :monthly, :last_6_months
          Date.current.end_of_month.to_date
        when :quarterly
          Date.current.end_of_quarter.to_date
        when :ytd, :custom
          Date.current
        else
          Date.current.end_of_month.to_date
        end
      end

      def build_previous_period
        duration = (end_date - start_date).to_i
        previous_end = start_date - 1.day
        previous_start = previous_end - duration.days

        Period.custom(start_date: previous_start, end_date: previous_end)
      end

      def ensure_money(value)
        return value if value.is_a?(Money)
        Money.new(value || 0, family.currency)
      end

      def build_summary_metrics
        current_income_totals = family.income_statement.income_totals(period: period)
        current_expense_totals = family.income_statement.expense_totals(period: period)

        previous_income_totals = family.income_statement.income_totals(period: previous_period)
        previous_expense_totals = family.income_statement.expense_totals(period: previous_period)

        current_income = ensure_money(current_income_totals.total)
        current_expenses = ensure_money(current_expense_totals.total)
        net_savings = current_income - current_expenses

        previous_income = ensure_money(previous_income_totals.total)
        previous_expenses = ensure_money(previous_expense_totals.total)

        income_change = calculate_percentage_change(previous_income, current_income)
        expense_change = calculate_percentage_change(previous_expenses, current_expenses)
        budget_percent = calculate_budget_performance

        {
          income: current_income.amount.to_f,
          income_change_pct: income_change,
          expense: current_expenses.amount.to_f,
          expense_change_pct: expense_change,
          net_savings: net_savings.amount.to_f,
          budget_used_pct: budget_percent
        }
      end

      def calculate_percentage_change(previous_value, current_value)
        return 0.0 if previous_value.zero?

        ((current_value - previous_value) / previous_value * 100).round(1).to_f
      end

      def calculate_budget_performance
        return nil unless period_type == :monthly && start_date.beginning_of_month.to_date == Date.current.beginning_of_month.to_date

        budget = Budget.find_or_bootstrap(family, start_date: start_date.beginning_of_month.to_date, user: user)
        return 0.0 if budget.nil? || budget.allocated_spending.zero?

        (budget.actual_spending / budget.allocated_spending * 100).round(1).to_f
      rescue StandardError
        nil
      end

      def build_trends_data
        trends = []
        current_month = start_date.beginning_of_month
        end_of_period = end_date.end_of_month

        while current_month <= end_of_period
          month_start = current_month
          month_end = current_month.end_of_month
          month_end = end_date if month_end > end_date

          m_period = Period.custom(start_date: month_start, end_date: month_end)

          income_val = family.income_statement.income_totals(period: m_period).total
          expenses_val = family.income_statement.expense_totals(period: m_period).total

          income_money = ensure_money(income_val)
          expenses_money = ensure_money(expenses_val)
          net_money = income_money - expenses_money

          trends << {
            month: month_start.strftime("%Y-%m"),
            month_name: month_start.strftime("%b %Y"),
            is_current_month: (month_start.month == Date.current.month && month_start.year == Date.current.year),
            income: income_money.amount.to_f,
            expense: expenses_money.amount.to_f,
            net: net_money.amount.to_f
          }

          current_month = current_month.next_month
        end

        trends
      end

      def build_net_worth_metrics
        balance_sheet = family.balance_sheet
        current_net_worth = balance_sheet.net_worth_money
        total_assets = balance_sheet.assets.total_money
        total_liabilities = balance_sheet.liabilities.total_money

        net_worth_series = balance_sheet.net_worth_series(period: period)
        trend = net_worth_series&.trend

        change_amount = trend ? trend.value.to_f : 0.0
        change_pct = trend && trend.percent.finite? ? trend.percent.to_f : nil

        {
          current: current_net_worth.amount.to_f,
          total_assets: total_assets.amount.to_f,
          total_liabilities: total_liabilities.amount.to_f,
          change: change_amount,
          change_pct: change_pct
        }
      end

      def build_transactions_breakdown
        # Base query for transactions in the period
        transactions = Transaction
          .joins(:entry)
          .joins(entry: :account)
          .where(accounts: { family_id: family.id, status: [ "draft", "active" ] })
          .where(entries: { entryable_type: "Transaction", excluded: false, date: period.date_range })
          .where.not(kind: Transaction::BUDGET_EXCLUDED_KINDS)
          .includes(entry: :account, category: :parent)

        transactions = apply_user_finance_accounts_filter(transactions)

        # Base query for trades in the period
        trades = Trade
          .joins(:entry)
          .joins(entry: :account)
          .where(accounts: { family_id: family.id, status: [ "draft", "active" ] })
          .where(entries: { entryable_type: "Trade", excluded: false, date: period.date_range })
          .includes(entry: :account, category: :parent)

        trades = apply_user_finance_accounts_filter(trades)

        grouped_data = {}
        family_currency = family.currency

        init_category_group = ->(id, name, color, icon, type) do
          {
            category_id: id.to_s,
            category_name: name,
            category_color: color,
            category_icon: icon,
            type: type,
            total: 0.0,
            count: 0,
            subcategories: {}
          }
        end

        init_subcategory = ->(cat) do
          {
            category_id: cat.id.to_s,
            category_name: cat.name,
            category_color: cat.color,
            category_icon: cat.lucide_icon,
            total: 0.0,
            count: 0
          }
        end

        process_entry = ->(category, entry, is_trade) do
          type = entry.amount > 0 ? "expense" : "income"
          begin
            converted_amount = Money.new(entry.amount.abs, entry.currency).exchange_to(family_currency).amount.to_f
          rescue Money::ConversionError
            converted_amount = entry.amount.abs.to_f
          end

          if category.nil?
            if is_trade
              parent_key = [ :other_investments, type ]
              grouped_data[parent_key] ||= init_category_group.call(:other_investments, Category.other_investments.name, Category.other_investments.color, Category.other_investments.lucide_icon, type)
            else
              parent_key = [ :uncategorized, type ]
              grouped_data[parent_key] ||= init_category_group.call(:uncategorized, Category.uncategorized.name, Category.uncategorized.color, Category.uncategorized.lucide_icon, type)
            end
          elsif category.parent_id.present?
            parent = category.parent
            parent_key = [ parent.id, type ]
            grouped_data[parent_key] ||= init_category_group.call(parent.id, parent.name, parent.color || Category::UNCATEGORIZED_COLOR, parent.lucide_icon, type)

            grouped_data[parent_key][:subcategories][category.id] ||= init_subcategory.call(category)
            grouped_data[parent_key][:subcategories][category.id][:count] += 1
            grouped_data[parent_key][:subcategories][category.id][:total] = (grouped_data[parent_key][:subcategories][category.id][:total] + converted_amount).round(2)
          else
            parent_key = [ category.id, type ]
            grouped_data[parent_key] ||= init_category_group.call(category.id, category.name, category.color || Category::UNCATEGORIZED_COLOR, category.lucide_icon, type)
          end

          grouped_data[parent_key][:count] += 1
          grouped_data[parent_key][:total] = (grouped_data[parent_key][:total] + converted_amount).round(2)
        end

        transactions.each do |tx|
          process_entry.call(tx.category, tx.entry, false)
        end

        trades.each do |tr|
          process_entry.call(tr.category, tr.entry, true)
        end

        income_groups = []
        expense_groups = []

        grouped_data.values.each do |parent_data|
          subs = parent_data[:subcategories].values.sort_by { |s| -s[:total] }
          group_item = parent_data.except(:type).merge(subcategories: subs)

          if parent_data[:type] == "income"
            income_groups << group_item
          else
            expense_groups << group_item
          end
        end

        {
          income: income_groups.sort_by { |g| -g[:total] },
          expense: expense_groups.sort_by { |g| -g[:total] }
        }
      end

      def apply_user_finance_accounts_filter(scope)
        return scope unless user

        finance_account_ids = user.finance_accounts.pluck(:id)
        scope.where(entries: { account_id: finance_account_ids })
      end
  end
end
