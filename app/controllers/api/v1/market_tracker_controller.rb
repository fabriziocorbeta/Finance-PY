# frozen_string_literal: true

class Api::V1::MarketTrackerController < Api::V1::BaseController
  before_action :ensure_read_scope

  # GET /api/v1/market_tracker
  def show
    range = Investments::MarketTrackerService.valid_range(params[:range])
    selected_ticker = params[:ticker].presence || "^GSPC"
    selected_mic = params[:mic].presence
    force_refresh = resolve_force_refresh

    holdings = InvestmentStatement.new(current_family, user: current_resource_owner).current_holdings.to_a
    watchlist_items = current_family.watchlist_items.includes(:security).ordered
    watchlist_indices = watchlist_items.select { |item| item.category == "index" }
    watchlist_assets = watchlist_items.reject { |item| item.category == "index" }

    tracker = Investments::MarketTrackerService.new
    index_quotes = tracker.index_quotes(watchlist_indices: watchlist_indices, force_refresh: force_refresh)
    watchlist_quotes = tracker.watchlist_quotes(watchlist_assets, force_refresh: force_refresh)
    holding_quotes = tracker.holding_quotes(holdings, force_refresh: force_refresh)

    selected_security, selected_watchlist = resolve_selected_context(selected_ticker, selected_mic, watchlist_items, holdings)
    featured_quote = tracker.quote_for(
      ticker: selected_ticker,
      exchange_operating_mic: selected_mic,
      range: range,
      security: selected_security,
      watchlist_item: selected_watchlist,
      force_refresh: force_refresh
    ) || (index_quotes + watchlist_quotes + holding_quotes.values).find do |card|
      card.ticker.casecmp?(selected_ticker) && (selected_mic.blank? || card.security&.exchange_operating_mic.to_s.casecmp?(selected_mic))
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
    force_refresh = resolve_force_refresh(scope: "quote:#{selected_ticker.upcase}")

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

    # Cooldown manual refreshes to prevent Android/widget polling from triggering
    # upstream Yahoo Finance 429 rate limits on repeated refresh=1 requests.
    def resolve_force_refresh(scope: "all")
      return false unless params[:refresh] == "1" || params[:refresh] == "true"

      cooldown_key = "market_tracker_refresh_cooldown:#{current_family.id}:#{scope}"
      return false if Rails.cache.read(cooldown_key).present?

      Rails.cache.write(cooldown_key, true, expires_in: 30.seconds)
      true
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
      ohlc_by_date = (card.ohlc_points || []).each_with_object({}) do |pt, hash|
        key = pt[:date].respond_to?(:iso8601) ? pt[:date].iso8601 : pt[:date].to_s
        hash[key] = pt
      end

      points = (card.series&.values || []).map do |pt|
        date_str = pt.date.respond_to?(:iso8601) ? pt.date.iso8601 : pt.date.to_s
        ohlc = ohlc_by_date[date_str]
        {
          date: date_str,
          value: pt.value.to_f,
          open: ohlc&.dig(:open)&.to_f,
          high: ohlc&.dig(:high)&.to_f,
          low: ohlc&.dig(:low)&.to_f,
          volume: ohlc&.dig(:volume)
        }.compact
      end

      f = card.fundamentals
      fundamentals_json = if f
        {
          market_cap: f.market_cap&.to_f,
          pe_ratio: f.pe_ratio&.to_f,
          forward_pe: f.forward_pe&.to_f,
          eps: f.eps&.to_f,
          dividend_yield: f.dividend_yield&.to_f,
          beta: f.beta&.to_f,
          avg_volume: f.avg_volume,
          open_price: f.open_price&.to_f,
          bid: f.bid&.to_f,
          ask: f.ask&.to_f,
          target_mean_price: f.target_mean_price&.to_f,
          recommendation_key: f.recommendation_key,
          sector: f.sector,
          industry: f.industry,
          website: f.website,
          description: f.description,
          earnings_date: f.earnings_date,
          ex_dividend_date: f.ex_dividend_date,
          market_state: f.market_state,
          pre_market_price: f.pre_market_price&.to_f,
          pre_market_change_percent: f.pre_market_change_percent&.to_f,
          post_market_price: f.post_market_price&.to_f,
          post_market_change_percent: f.post_market_change_percent&.to_f
        }
      end

      news_json = (card.news || []).map do |item|
        {
          title: item.title,
          publisher: item.publisher,
          link: item.link,
          published_at: item.published_at
        }
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
        points: points,
        fundamentals: fundamentals_json,
        news: news_json
      }
    end
end
