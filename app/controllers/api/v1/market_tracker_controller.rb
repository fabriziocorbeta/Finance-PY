# frozen_string_literal: true

class Api::V1::MarketTrackerController < Api::V1::BaseController
  before_action :ensure_read_scope

  # GET /api/v1/market_tracker
  def show
    range = Investments::MarketTrackerService.valid_range(params[:range])
    selected_ticker = params[:ticker].presence || "^GSPC"
    selected_mic = params[:mic].presence
    force_refresh = params[:refresh] == "1" || params[:refresh] == "true"

    holdings = InvestmentStatement.new(current_family, user: current_resource_owner).current_holdings.to_a
    watchlist_items = current_family.watchlist_items.includes(:security).ordered
    watchlist_indices = watchlist_items.select { |item| item.category == "index" }
    watchlist_assets = watchlist_items.reject { |item| item.category == "index" }

    tracker = Investments::MarketTrackerService.new
    index_quotes = tracker.index_quotes(watchlist_indices: watchlist_indices, force_refresh: force_refresh)
    watchlist_quotes = tracker.watchlist_quotes(watchlist_assets, force_refresh: force_refresh)
    holding_quotes = tracker.holding_quotes(holdings, force_refresh: force_refresh)

    featured_quote = if range == "1mo" && !force_refresh
      (index_quotes + watchlist_quotes + holding_quotes.values).find do |card|
        card.ticker.casecmp?(selected_ticker) && (selected_mic.blank? || card.security&.exchange_operating_mic.to_s.casecmp?(selected_mic))
      end
    end

    featured_quote ||= begin
      selected_security, selected_watchlist = resolve_selected_context(selected_ticker, selected_mic, watchlist_items, holdings)
      tracker.quote_for(
        ticker: selected_ticker,
        exchange_operating_mic: selected_mic,
        range: range,
        security: selected_security,
        watchlist_item: selected_watchlist,
        force_refresh: force_refresh
      )
    end

    render json: {
      index_quotes: index_quotes.map { |q| serialize_quote(q) },
      watchlist_quotes: watchlist_quotes.map { |q| serialize_quote(q) },
      holding_quotes: holding_quotes.values.map { |q| serialize_quote(q) },
      featured_quote: featured_quote ? serialize_quote(featured_quote) : nil
    }
  rescue => e
    log_and_render_error("show", e)
  end

  # GET /api/v1/market_tracker/quote
  def quote
    range = Investments::MarketTrackerService.valid_range(params[:range])
    selected_ticker = params[:ticker].presence || "^GSPC"
    selected_mic = params[:mic].presence
    force_refresh = params[:refresh] == "1" || params[:refresh] == "true"

    watchlist_items = current_family.watchlist_items.includes(:security)
    holdings = InvestmentStatement.new(current_family, user: current_resource_owner).current_holdings.to_a
    selected_security, selected_watchlist = resolve_selected_context(selected_ticker, selected_mic, watchlist_items, holdings)

    card = Investments::MarketTrackerService.new.quote_for(
      ticker: selected_ticker,
      exchange_operating_mic: selected_mic,
      range: range,
      security: selected_security,
      watchlist_item: selected_watchlist,
      force_refresh: force_refresh
    )

    render json: { quote: card ? serialize_quote(card) : nil }
  rescue => e
    log_and_render_error("quote", e)
  end

  private
    def ensure_read_scope
      authorize_scope!(:read)
    end

    def resolve_selected_context(ticker, mic, watchlist_items, holdings)
      watchlist_item = watchlist_items.find do |item|
        item.ticker.casecmp?(ticker) && (mic.blank? || item.exchange_operating_mic.to_s.casecmp?(mic))
      end

      holding_security = holdings.find do |h|
        h.ticker.casecmp?(ticker) && (mic.blank? || h.security.exchange_operating_mic.to_s.casecmp?(mic))
      end&.security

      security = watchlist_item&.security || holding_security || Security.find_by("UPPER(ticker) = ?", ticker.upcase)
      [ security, watchlist_item ]
    end

    def serialize_quote(card)
      points = (card.series&.values || []).map do |pt|
        { date: pt.date.to_s, value: pt.value.to_f }
      end

      {
        ticker: card.ticker,
        name: card.name,
        category: card.category,
        currency: card.currency,
        exchange_name: card.exchange_name,
        current_price: card.current_price&.to_f,
        previous_close: card.previous_close&.to_f,
        change: card.change&.to_f,
        change_percent: card.change_percent&.to_f,
        period_change: card.period_change&.to_f,
        period_change_percent: card.period_change_percent&.to_f,
        day_high: card.day_high&.to_f,
        day_low: card.day_low&.to_f,
        fifty_two_week_high: card.fifty_two_week_high&.to_f,
        fifty_two_week_low: card.fifty_two_week_low&.to_f,
        volume: card.volume,
        watchlist_item_id: card.watchlist_item&.id,
        security_id: card.security&.id,
        points: points
      }
    end
end
