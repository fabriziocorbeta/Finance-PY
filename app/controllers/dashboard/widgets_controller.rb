module Dashboard
  class WidgetsController < ApplicationController
    layout false

    def available_to_spend
      render Dashboard::AvailableToSpendComponent.new(
        family: Current.family,
        user: Current.user,
        accounts: Current.finance_accounts
      )
    end

    def recent_expenses
      render Dashboard::RecentExpensesComponent.new(
        family: Current.family,
        accounts: Current.finance_accounts,
        limit: params.fetch(:limit, 5).to_i.clamp(1, 20)
      )
    end

    def budget_status
      render Dashboard::BudgetStatusComponent.new(
        family: Current.family,
        user: Current.user
      )
    end

    def sales_summary
      render Dashboard::SalesSummaryComponent.new(
        family: Current.family,
        period: current_month_range
      )
    end

    private

      def current_month_range
        Time.current.beginning_of_month..Time.current.end_of_month
      end
  end
end
