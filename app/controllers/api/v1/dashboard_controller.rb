# frozen_string_literal: true

# Aggregates the data needed to render the mobile app's home/dashboard screen:
# greeting, net worth (with historical series), cashflow sankey, outflows
# donut, balance sheet breakdown, and investment summary.
class Api::V1::DashboardController < Api::V1::BaseController
  before_action :ensure_read_scope

  # GET /api/v1/dashboard?period=last_30_days
  def show
    family = current_resource_owner.family
    period = resolve_period
    summary = Dashboard::SummaryBuilder.new(family: family, period: period)

    @greeting_name = current_resource_owner.first_name.presence || current_resource_owner.email
    @period = period
    @currency = family.currency
    @balance_sheet = summary.balance_sheet
    @net_worth_series = @balance_sheet.net_worth_series(period: period)
    @cashflow_sankey = summary.cashflow_sankey_data
    @outflows_donut = summary.outflows_donut_data
    @investment_statement = summary.investment_statement
    @has_investment_accounts = @investment_statement.investment_accounts.any?

    render :show
  rescue => e
    Rails.logger.error "DashboardController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def resolve_period
      return Period.from_key(params[:period]) if params[:period].present?

      Period.current_month_for(current_resource_owner.family)
    rescue Period::InvalidKeyError
      Period.current_month_for(current_resource_owner.family)
    end
end
