# frozen_string_literal: true

# Shared rate-lookup logic used by both the web (session-auth) and API
# (Bearer/API-key-auth) exchange rate endpoints, so the BigDecimal-precision
# and staleness handling lives in exactly one place.
class ExchangeRateLookup
  Result = Struct.new(:rate, :rate_date, :stale, :same_currency, :error, :rate_hint, keyword_init: true)

  def self.call(from:, to:, date: Date.current)
    new(from: from, to: to, date: date).call
  end

  def initialize(from:, to:, date: Date.current)
    @from = from.to_s.upcase
    @to = to.to_s.upcase
    @date = date || Date.current
  end

  def call
    return Result.new(rate: BigDecimal("1"), same_currency: true, stale: false) if @from == @to

    begin
      rate_obj = ExchangeRate.find_or_fetch_rate(from: @from, to: @to, date: @date)
    rescue StandardError
      return Result.new(error: :provider_error)
    end

    if rate_obj.nil?
      return Result.new(
        error: :not_found,
        rate_hint: I18n.t("shared.exchange_rate_tabs.rate_hint_unavailable")
      )
    end

    # BigDecimal end-to-end (never Float) so a rate like 6358.47021484375 or a
    # tiny inverse rate like 0.00015727... round-trips to the client with no
    # precision lost to binary floating point. find_or_fetch_rate can return
    # either a raw Numeric or an ExchangeRate-like object with a #rate method.
    rate_value = rate_obj.is_a?(Numeric) ? BigDecimal(rate_obj.to_s) : rate_obj.rate.to_d

    # find_or_fetch_rate can silently return a rate from an earlier date
    # (weekend/holiday carry-forward, or the nearest cached rate within its
    # lookback window) -- surface that explicitly instead of letting the
    # caller assume it's today's rate. Some callers (plain Numeric, or a mock
    # without a #date) won't respond to :date, so fall back to the requested date.
    rate_date = rate_obj.respond_to?(:date) ? rate_obj.date : @date
    stale = rate_date != @date

    Result.new(
      rate: rate_value,
      rate_date: rate_date,
      stale: stale,
      same_currency: false,
      rate_hint: I18n.t(
        stale ? "shared.exchange_rate_tabs.rate_hint_stale" : "shared.exchange_rate_tabs.rate_hint_current",
        date: rate_date.to_s
      )
    )
  end
end
