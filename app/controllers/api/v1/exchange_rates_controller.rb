# frozen_string_literal: true

# Bearer/API-key-reachable twin of ExchangeRatesController, for mobile clients
# that authenticate via OAuth2/API key instead of a web session.
class Api::V1::ExchangeRatesController < Api::V1::BaseController
  before_action :ensure_read_scope

  # GET /api/v1/exchange_rate?from=&to=&date=
  def show
    unless params[:from].present? && params[:to].present?
      return render json: { error: "bad_request", message: "from and to currencies are required" }, status: :bad_request
    end

    from_currency = params[:from].upcase
    to_currency = params[:to].upcase

    begin
      date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    rescue ArgumentError, TypeError
      return render json: { error: "bad_request", message: "Invalid date format" }, status: :bad_request
    end

    result = ExchangeRateLookup.call(from: from_currency, to: to_currency, date: date)

    if result.same_currency
      render json: { rate: result.rate.to_s("F"), same_currency: true }
    elsif result.error == :not_found
      render json: {
        error: "not_found",
        message: "Exchange rate not found",
        rate_hint: result.rate_hint
      }, status: :not_found
    elsif result.error == :provider_error
      render json: { error: "validation_failed", message: "Failed to fetch exchange rate" }, status: :unprocessable_entity
    else
      render json: {
        rate: result.rate.to_s("F"),
        rate_date: result.rate_date.to_s,
        stale: result.stale,
        rate_hint: result.rate_hint
      }
    end
  end

  private

    def ensure_read_scope
      authorize_scope!(:read)
    end
end
