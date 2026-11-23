module Dashboard
  class SalesSummaryComponent < BaseWidgetComponent
    def initialize(family:, period: Time.current.beginning_of_month..Time.current.end_of_month)
      super(family: family)
      @period = period
    end

    def current_sales
      @current_sales ||= family.sales.completed.includes(:sale_items).where(created_at: @period).to_a
    end

    def previous_sales
      prev_period = (@period.begin - 1.month)..(@period.end - 1.month)
      @previous_sales ||= family.sales.completed.includes(:sale_items).where(created_at: prev_period).to_a
    end

    def total_sales_money
      @total_sales_money ||= sum_sales_in_family_currency(current_sales)
    end

    def previous_sales_money
      @previous_sales_money ||= sum_sales_in_family_currency(previous_sales)
    end

    def sales_count
      current_sales.size
    end

    def average_ticket_money
      return zero_money if sales_count.zero?

      Money.new((total_sales_money.amount / sales_count).round(2), family_currency)
    end

    def growth_percentage
      return nil if previous_sales_money.amount <= 0

      (((total_sales_money.amount - previous_sales_money.amount) / previous_sales_money.amount) * 100).round(1).to_f
    end

    private

      def sum_sales_in_family_currency(sales)
        sum_in_family_currency(sales) do |sale|
          to_family_money(sale.total, sale.currency, date: sale.created_at.to_date)
        end
      end
  end
end
