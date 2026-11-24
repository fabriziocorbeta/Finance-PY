class InvestmentsController < ApplicationController
  include AccountableResource

  permitted_accountable_attributes :id, :subtype

  skip_before_action :set_account, only: %i[index quote sync]
  skip_before_action :set_manageable_account, only: %i[index quote sync]
  skip_before_action :set_link_options, only: %i[index quote sync]

  def index
    @range = Investments::MarketTrackerService.valid_range(params[:range])
    @selected_ticker = params[:ticker].presence || "^GSPC"
    @selected_mic = params[:mic].presence
    force_refresh = params[:refresh] == "1"

    @investment_statement = InvestmentStatement.new(Current.family, user: Current.user)
    @holdings = @investment_statement.current_holdings.to_a
    @watchlist_items = Current.family.watchlist_items.includes(:security).ordered
    @watchlist_indices = @watchlist_items.select { |item| item.category == "index" }
    @watchlist_assets = @watchlist_items.reject { |item| item.category == "index" }

    tracker = Investments::MarketTrackerService.new
    @index_quotes = tracker.index_quotes(watchlist_indices: @watchlist_indices, force_refresh: force_refresh)
    @watchlist_quotes = tracker.watchlist_quotes(@watchlist_assets, force_refresh: force_refresh)
    @holding_quotes = tracker.holding_quotes(@holdings, force_refresh: force_refresh)

    selected_security, selected_watchlist = resolve_selected_context(@selected_ticker, @selected_mic)
    @featured_quote = tracker.quote_for(
      ticker: @selected_ticker,
      exchange_operating_mic: @selected_mic,
      range: @range,
      security: selected_security,
      watchlist_item: selected_watchlist,
      force_refresh: force_refresh
    )

    @portfolio_day_change = calculate_portfolio_day_change(@holdings, @holding_quotes)
  end

  def quote
    @range = Investments::MarketTrackerService.valid_range(params[:range])
    @selected_ticker = params[:ticker].presence || "^GSPC"
    @selected_mic = params[:mic].presence

    @watchlist_items = Current.family.watchlist_items.includes(:security)
    @holdings = InvestmentStatement.new(Current.family, user: Current.user).current_holdings.to_a

    selected_security, selected_watchlist = resolve_selected_context(@selected_ticker, @selected_mic)
    @featured_quote = Investments::MarketTrackerService.new.quote_for(
      ticker: @selected_ticker,
      exchange_operating_mic: @selected_mic,
      range: @range,
      security: selected_security,
      watchlist_item: selected_watchlist,
      force_refresh: params[:refresh] == "1"
    )

    render partial: "investments/quote_detail", locals: {
      quote: @featured_quote,
      range: @range,
      selected_ticker: @selected_ticker,
      selected_mic: @selected_mic
    }
  end

  def sync
    redirect_to investments_path(
      ticker: params[:ticker].presence || "^GSPC",
      mic: params[:mic].presence,
      range: Investments::MarketTrackerService.valid_range(params[:range]),
      refresh: "1"
    ), notice: t("investments.index.synced")
  end

  private
    def resolve_selected_context(ticker, mic)
      watchlist_item = @watchlist_items.find do |item|
        item.ticker.casecmp?(ticker) && (mic.blank? || item.exchange_operating_mic.to_s.casecmp?(mic))
      end

      holding_security = @holdings.find do |h|
        h.ticker.casecmp?(ticker) && (mic.blank? || h.security.exchange_operating_mic.to_s.casecmp?(mic))
      end&.security

      security = watchlist_item&.security || holding_security || Security.find_by("UPPER(ticker) = ?", ticker.upcase)
      [ security, watchlist_item ]
    end

    def calculate_portfolio_day_change(holdings, holding_quotes)
      total_change = 0.to_d
      total_prev_value = 0.to_d

      holdings.each do |holding|
        quote = holding_quotes[holding.security_id]
        next unless quote&.change && quote&.previous_close&.nonzero?

        native_change = quote.change.to_d * holding.qty.to_d
        native_prev = quote.previous_close.to_d * holding.qty.to_d

        total_change += convert_amount_to_family_currency(native_change, holding.currency)
        total_prev_value += convert_amount_to_family_currency(native_prev, holding.currency)
      end

      percent = total_prev_value.positive? ? ((total_change / total_prev_value) * 100).round(2) : nil
      { amount: Money.new(total_change, Current.family.currency), percent: percent }
    end

    def convert_amount_to_family_currency(amount, from_currency)
      return amount if from_currency.blank? || from_currency == Current.family.currency

      Money.new(amount, from_currency).exchange_to(Current.family.currency).amount
    rescue Money::Currency::UnknownCurrency, ExchangeRate::MissingRateError
      amount
    end
end
