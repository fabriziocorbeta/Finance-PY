class ExchangeRatesController < ApplicationController
  def show
    # Pure currency-to-currency exchange rate lookup
    unless params[:from].present? && params[:to].present?
      return render json: { error: "from and to currencies are required" }, status: :bad_request
    end

    from_currency = params[:from].upcase
    to_currency = params[:to].upcase

    # Parse date
    begin
      date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    rescue ArgumentError, TypeError
      return render json: { error: "Invalid date format" }, status: :bad_request
    end

    result = ExchangeRateLookup.call(from: from_currency, to: to_currency, date: date)

    if result.same_currency
      render json: { rate: result.rate.to_s("F"), same_currency: true }
    elsif result.error == :not_found
      render json: {
        error: "Exchange rate not found",
        rate_hint: result.rate_hint
      }, status: :not_found
    elsif result.error == :provider_error
      render json: { error: "Failed to fetch exchange rate" }, status: :bad_request
    else
      render json: {
        rate: result.rate.to_s("F"),
        rate_date: result.rate_date.to_s,
        stale: result.stale,
        rate_hint: result.rate_hint
      }
    end
  end
end
