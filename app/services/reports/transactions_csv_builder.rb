# frozen_string_literal: true

require "csv"

module Reports
  class TransactionsCsvBuilder
    ALLOWED_PERIOD_TYPES = %w[monthly quarterly ytd last_6_months custom].freeze

    attr_reader :family, :user, :period_type, :start_date, :end_date, :period

    def initialize(family:, user: nil, period_type: "monthly", start_date: nil, end_date: nil, params: {})
      @family = family
      @user = user
      @period_type = (period_type.to_s.presence_in(ALLOWED_PERIOD_TYPES) || "monthly").to_sym
      @params = params || {}
      parse_dates(start_date, end_date)
      @period = Period.custom(start_date: @start_date, end_date: @end_date)
    end

    def filename
      "transactions_breakdown_#{@start_date.strftime('%Y%m%d')}_to_#{@end_date.strftime('%Y%m%d')}.csv"
    end

    def build_monthly_breakdown
      months = []
      current_month = @start_date.beginning_of_month
      end_of_period = @end_date.end_of_month

      while current_month <= end_of_period
        months << current_month
        current_month = current_month.next_month
      end

      transactions = Transaction
        .joins(:entry)
        .joins(entry: :account)
        .where(accounts: { family_id: family.id, status: [ "draft", "active" ] })
        .where(entries: { entryable_type: "Transaction", excluded: false, date: period.date_range })
        .where.not(kind: Transaction::BUDGET_EXCLUDED_KINDS)
        .includes(entry: :account, category: [])

      transactions = apply_transaction_filters(transactions)

      breakdown = {}
      family_currency = family.currency

      transactions.each do |transaction|
        entry = transaction.entry
        is_expense = entry.amount > 0
        type = is_expense ? "expense" : "income"
        category_name = transaction.category&.name || "Uncategorized"
        month_key = entry.date.beginning_of_month

        begin
          converted_amount = Money.new(entry.amount.abs, entry.currency).exchange_to(family_currency).amount
        rescue Money::ConversionError
          converted_amount = entry.amount.abs
        end

        key = [ category_name, type ]
        breakdown[key] ||= { category: category_name, type: type, months: {}, total: 0 }
        breakdown[key][:months][month_key] ||= 0
        breakdown[key][:months][month_key] += converted_amount
        breakdown[key][:total] += converted_amount
      end

      result = breakdown.map do |_key, data|
        {
          category: data[:category],
          type: data[:type],
          months: data[:months],
          total: data[:total]
        }
      end

      income_data = result.select { |r| r[:type] == "income" }.sort_by { |r| -r[:total] }
      expense_data = result.select { |r| r[:type] == "expense" }.sort_by { |r| -r[:total] }

      {
        months: months,
        income: income_data,
        expenses: expense_data
      }
    end

    def generate_csv
      export_data = build_monthly_breakdown

      CSV.generate do |csv|
        month_headers = export_data[:months].map { |m| m.strftime("%b %Y") }
        header_row = [ "Category" ] + month_headers + [ "Total" ]
        csv << header_row

        if export_data[:income].any?
          csv << [ "INCOME" ] + Array.new(month_headers.length + 1, "")

          export_data[:income].each do |category_data|
            row = [ category_data[:category] ]

            export_data[:months].each do |month|
              amount = category_data[:months][month] || 0
              row << Money.new(amount, family.currency).format
            end

            row << Money.new(category_data[:total], family.currency).format
            csv << row
          end

          totals_row = [ "TOTAL INCOME" ]
          export_data[:months].each do |month|
            month_total = export_data[:income].sum { |c| c[:months][month] || 0 }
            totals_row << Money.new(month_total, family.currency).format
          end
          grand_income_total = export_data[:income].sum { |c| c[:total] }
          totals_row << Money.new(grand_income_total, family.currency).format
          csv << totals_row

          csv << []
        end

        if export_data[:expenses].any?
          csv << [ "EXPENSES" ] + Array.new(month_headers.length + 1, "")

          export_data[:expenses].each do |category_data|
            row = [ category_data[:category] ]

            export_data[:months].each do |month|
              amount = category_data[:months][month] || 0
              row << Money.new(amount, family.currency).format
            end

            row << Money.new(category_data[:total], family.currency).format
            csv << row
          end

          totals_row = [ "TOTAL EXPENSES" ]
          export_data[:months].each do |month|
            month_total = export_data[:expenses].sum { |c| c[:months][month] || 0 }
            totals_row << Money.new(month_total, family.currency).format
          end
          grand_expenses_total = export_data[:expenses].sum { |c| c[:total] }
          totals_row << Money.new(grand_expenses_total, family.currency).format
          csv << totals_row
        end
      end
    end

    private

      def parse_dates(start_date_param, end_date_param)
        s_date = parse_date(start_date_param) || default_start_date
        e_date = parse_date(end_date_param) || default_end_date

        s_date, e_date = e_date, s_date if s_date > e_date

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

      def apply_transaction_filters(scope)
        scope = apply_entry_filters(scope)

        if @params[:filter_tag_id].present?
          scope = scope.joins(:taggings).where(taggings: { tag_id: @params[:filter_tag_id] })
        end

        scope
      end

      def apply_entry_filters(scope)
        if user
          finance_account_ids = user.finance_accounts.pluck(:id)
          scope = scope.where(entries: { account_id: finance_account_ids })
        end

        if @params[:filter_category_id].present?
          category_id = @params[:filter_category_id]
          subcategory_ids = family.categories.where(parent_id: category_id).pluck(:id)
          all_category_ids = [ category_id ] + subcategory_ids
          scope = scope.where(category_id: all_category_ids)
        end

        if @params[:filter_account_id].present?
          scope = scope.where(entries: { account_id: @params[:filter_account_id] })
        end

        if @params[:filter_amount_min].present?
          scope = scope.where("ABS(entries.amount) >= ?", @params[:filter_amount_min].to_f)
        end

        if @params[:filter_amount_max].present?
          scope = scope.where("ABS(entries.amount) <= ?", @params[:filter_amount_max].to_f)
        end

        if @params[:filter_date_start].present?
          filter_start = Date.parse(@params[:filter_date_start].to_s)
          scope = scope.where("entries.date >= ?", filter_start) if filter_start >= @start_date
        end

        if @params[:filter_date_end].present?
          filter_end = Date.parse(@params[:filter_date_end].to_s)
          scope = scope.where("entries.date <= ?", filter_end) if filter_end <= @end_date
        end

        scope
      rescue Date::Error
        scope
      end
  end
end
