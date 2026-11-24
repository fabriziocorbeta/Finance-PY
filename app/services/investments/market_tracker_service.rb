module Investments
  class MarketTrackerService
    DEFAULT_INDICES = [
      { ticker: "^GSPC", name: "S&P 500", region: "US" },
      { ticker: "^IXIC", name: "Nasdaq Composite", region: "US" },
      { ticker: "^DJI", name: "Dow Jones", region: "US" },
      { ticker: "^RUT", name: "Russell 2000", region: "US" },
      { ticker: "^VIX", name: "VIX", region: "US" }
    ].freeze

    RANGE_CONFIG = {
      "5d" => { range: "5d", interval: "1d" },
      "1mo" => { range: "1mo", interval: "1d" },
      "3mo" => { range: "3mo", interval: "1d" },
      "6mo" => { range: "6mo", interval: "1d" },
      "ytd" => { range: "ytd", interval: "1d" },
      "1y" => { range: "1y", interval: "1d" },
      "5y" => { range: "5y", interval: "1wk" }
    }.freeze

    FETCH_TIMEOUT = 10.seconds

    QuoteCard = Data.define(
      :ticker,
      :name,
      :category,
      :currency,
      :exchange_name,
      :current_price,
      :previous_close,
      :change,
      :change_percent,
      :period_change,
      :period_change_percent,
      :day_high,
      :day_low,
      :fifty_two_week_high,
      :fifty_two_week_low,
      :volume,
      :series,
      :security,
      :watchlist_item
    ) do
      def positive?
        change.to_f >= 0
      end

      def period_positive?
        period_change.to_f >= 0
      end
    end

    def initialize(provider: nil)
      @provider = provider || Provider::YahooFinance.new
    end

    def self.valid_range(range)
      RANGE_CONFIG.key?(range.to_s) ? range.to_s : "1mo"
    end

    # Returns QuoteCard objects for major market indices plus any family-watched indices.
    def index_quotes(watchlist_indices: [], force_refresh: false)
      targets = DEFAULT_INDICES.map do |idx|
        watched = watchlist_indices.find { |w| w.ticker.casecmp?(idx[:ticker]) }
        { ticker: idx[:ticker], fallback_name: idx[:name], category: "index", watchlist_item: watched, security: watched&.security }
      end

      watchlist_indices.each do |item|
        next if targets.any? { |t| t[:ticker].casecmp?(item.ticker) }

        targets << {
          ticker: item.ticker,
          fallback_name: item.name || item.ticker,
          category: "index",
          watchlist_item: item,
          security: item.security
        }
      end

      fetch_batch(targets, range: "1mo", force_refresh: force_refresh)
    end

    # Returns QuoteCard objects for non-index watchlist items (ETFs, stocks, crypto, funds).
    def watchlist_quotes(watchlist_items, force_refresh: false)
      targets = watchlist_items.map do |item|
        {
          ticker: item.ticker,
          fallback_name: item.name || item.ticker,
          exchange_operating_mic: item.exchange_operating_mic,
          category: item.category,
          watchlist_item: item,
          security: item.security
        }
      end

      fetch_batch(targets, range: "1mo", force_refresh: force_refresh)
    end

    # Returns a Hash of security_id => QuoteCard for the family's current holdings.
    def holding_quotes(holdings, force_refresh: false)
      securities = holdings.map(&:security).compact.uniq(&:id)
      targets = securities.map do |sec|
        {
          ticker: sec.ticker,
          fallback_name: sec.name || sec.ticker,
          exchange_operating_mic: sec.exchange_operating_mic,
          category: WatchlistItem.infer_category(ticker: sec.ticker),
          security: sec
        }
      end

      cards = fetch_batch(targets, range: "1mo", force_refresh: force_refresh)
      cards.each_with_object({}) do |card, hash|
        hash[card.security.id] = card if card.security
      end
    end

    # Fetches detailed quote + historical Series for a single ticker and timeframe.
    def quote_for(ticker:, exchange_operating_mic: nil, range: "1mo", security: nil, watchlist_item: nil, force_refresh: false)
      range_key = self.class.valid_range(range)
      cfg = RANGE_CONFIG[range_key]

      fetch_single(
        ticker: ticker,
        fallback_name: security&.name || ticker,
        exchange_operating_mic: exchange_operating_mic || security&.exchange_operating_mic,
        category: watchlist_item&.category || WatchlistItem.infer_category(ticker: ticker),
        security: security,
        watchlist_item: watchlist_item,
        range: cfg[:range],
        interval: cfg[:interval],
        force_refresh: force_refresh
      )
    end

    private
      def fetch_batch(targets, range: "1mo", force_refresh: false)
        return [] if targets.empty?

        cfg = RANGE_CONFIG[self.class.valid_range(range)]
        futures = targets.map do |target|
          Concurrent::Promises.future(target) do |t|
            fetch_single(
              ticker: t[:ticker],
              fallback_name: t[:fallback_name],
              exchange_operating_mic: t[:exchange_operating_mic],
              category: t[:category],
              security: t[:security],
              watchlist_item: t[:watchlist_item],
              range: cfg[:range],
              interval: cfg[:interval],
              force_refresh: force_refresh
            )
          end
        end

        deadline = Time.current + FETCH_TIMEOUT
        futures.map.with_index do |future, idx|
          remaining = [ (deadline - Time.current), 0 ].max
          future.value(remaining) || fallback_card(targets[idx])
        end
      end

      def fetch_single(ticker:, fallback_name:, exchange_operating_mic: nil, category: "equity", security: nil, watchlist_item: nil, range: "1mo", interval: "1d", force_refresh: false)
        response = @provider.fetch_quote_and_series(
          symbol: ticker,
          exchange_operating_mic: exchange_operating_mic,
          range: range,
          interval: interval,
          clear_cache: force_refresh
        )

        if response.success? && response.data
          build_card_from_provider(
            response.data,
            fallback_name: fallback_name,
            category: category,
            security: security,
            watchlist_item: watchlist_item
          )
        else
          fallback_card({
            ticker: ticker,
            fallback_name: fallback_name,
            category: category,
            security: security,
            watchlist_item: watchlist_item
          })
        end
      rescue => e
        Rails.logger.warn("MarketTrackerService failed for #{ticker}: #{e.message}")
        fallback_card({
          ticker: ticker,
          fallback_name: fallback_name,
          category: category,
          security: security,
          watchlist_item: watchlist_item
        })
      end

      def build_card_from_provider(data, fallback_name:, category:, security:, watchlist_item:)
        points = data.prices || []
        series = build_series(points)

        first_price = points.first&.dig(:price)
        current = data.current_price || points.last&.dig(:price)
        period_change = (current && first_price) ? (current - first_price).round(4) : nil
        period_change_pct = (period_change && first_price&.nonzero?) ? ((period_change / first_price) * 100).round(2) : nil

        inferred_category = if data.instrument_type.present?
          WatchlistItem.infer_category(ticker: data.symbol, quote_type: data.instrument_type)
        else
          category
        end

        QuoteCard.new(
          ticker: data.symbol,
          name: data.short_name.presence || data.name.presence || fallback_name,
          category: inferred_category,
          currency: data.currency || "USD",
          exchange_name: data.exchange_name,
          current_price: current,
          previous_close: data.previous_close,
          change: data.change,
          change_percent: data.change_percent,
          period_change: period_change,
          period_change_percent: period_change_pct,
          day_high: data.day_high,
          day_low: data.day_low,
          fifty_two_week_high: data.fifty_two_week_high,
          fifty_two_week_low: data.fifty_two_week_low,
          volume: data.volume,
          series: series,
          security: security,
          watchlist_item: watchlist_item
        )
      end

      def fallback_card(target)
        security = target[:security]
        db_prices = if security
          security.prices.where(date: 31.days.ago.to_date..Date.current).order(:date).map { |p| { date: p.date, price: p.price.to_f } }
        else
          []
        end

        current = db_prices.last&.dig(:price)
        prev = db_prices.size >= 2 ? db_prices[-2][:price] : nil
        change = (current && prev) ? (current - prev).round(4) : nil
        change_pct = (change && prev&.nonzero?) ? ((change / prev) * 100).round(2) : nil

        QuoteCard.new(
          ticker: target[:ticker],
          name: target[:fallback_name] || target[:ticker],
          category: target[:category] || "equity",
          currency: security&.prices&.last&.currency || "USD",
          exchange_name: security&.exchange_name,
          current_price: current,
          previous_close: prev,
          change: change,
          change_percent: change_pct,
          period_change: nil,
          period_change_percent: nil,
          day_high: nil,
          day_low: nil,
          fifty_two_week_high: nil,
          fifty_two_week_low: nil,
          volume: nil,
          series: build_series(db_prices),
          security: security,
          watchlist_item: target[:watchlist_item]
        )
      end

      def build_series(points)
        return nil if points.blank? || points.size < 2

        raw_values = points.map { |pt| { date: pt[:date], value: pt[:price] } }
        Series.from_raw_values(raw_values)
      rescue ArgumentError
        nil
      end
  end
end
