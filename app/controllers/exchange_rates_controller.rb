class ExchangeRatesController < ApplicationController
  def show
    # Pure currency-to-currency exchange rate lookup
    unless params[:from].present? && params[:to].present?
      return render json: { error: "from and to currencies are required" }, status: :bad_request
    end

    from_currency = params[:from].upcase
    to_currency = params[:to].upcase

    # Same currency returns 1.0
    if from_currency == to_currency
      return render json: { rate: "1.0", same_currency: true }
    end

    # Parse date
    begin
      date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    rescue ArgumentError, TypeError
      return render json: { error: "Invalid date format" }, status: :bad_request
    end

    begin
      rate_obj = ExchangeRate.find_or_fetch_rate(from: from_currency, to: to_currency, date: date)
    rescue StandardError
      return render json: { error: "Failed to fetch exchange rate" }, status: :bad_request
    end

    if rate_obj.nil?
      return render json: {
        error: "Exchange rate not found",
        rate_hint: t("shared.exchange_rate_tabs.rate_hint_unavailable")
      }, status: :not_found
    end

    # BigDecimal end-to-end (never Float) so a rate like 6358.47021484375 or a
    # tiny inverse rate like 0.00015727... round-trips to the client, into the
    # form field, and back into the saved transaction with no precision lost
    # to binary floating point.
    rate_value = rate_obj.is_a?(Numeric) ? BigDecimal(rate_obj.to_s) : rate_obj.rate.to_d

    # find_or_fetch_rate can silently return a rate from an earlier date
    # (weekend/holiday carry-forward, or the nearest cached rate within its
    # lookback window) -- surface that explicitly instead of letting the
    # client assume it's today's rate.
    rate_date = rate_obj.respond_to?(:date) ? rate_obj.date : date
    stale = rate_date != date

    render json: {
      rate: rate_value.to_s("F"),
      rate_date: rate_date.to_s,
      stale: stale,
      rate_hint: t(
        stale ? "shared.exchange_rate_tabs.rate_hint_stale" : "shared.exchange_rate_tabs.rate_hint_current",
        date: rate_date.to_s
      )
    }
  end
end
