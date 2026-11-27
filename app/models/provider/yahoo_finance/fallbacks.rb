module Provider::YahooFinance::Fallbacks
  extend ActiveSupport::Concern

  COINGECKO_BASE_URL = "https://api.coingecko.com/api/v3".freeze
  NASDAQ_BASE_URL = "https://api.nasdaq.com/api".freeze
  US_MICS = %w[XNAS XNYS ARCX XASE BATS IEX].freeze

  SP500_FALLBACK_SECURITIES = [
    { symbol: "SPY", name: "State Street SPDR S&P 500 ETF Trust", mic: "ARCX", country: "US" },
    { symbol: "VOO", name: "Vanguard S&P 500 ETF", mic: "ARCX", country: "US" },
    { symbol: "IVV", name: "iShares Core S&P 500 ETF", mic: "ARCX", country: "US" },
    { symbol: "^GSPC", name: "S&P 500", mic: nil, country: "US" },
    { symbol: "SPYON-USD", name: "SPDR S&P 500 ETF (Ondo Tokenized ETF)", mic: nil, country: nil }
  ].freeze

  private
    def fallback_search_securities(clean_symbol)
      return [] if clean_symbol.blank? || clean_symbol.length > 20 || !clean_symbol.match?(/\A[A-Z0-9.\-&\s^]+\z/)

      if %w[SP500 S&P500 S&P\ 500].include?(clean_symbol)
        return fallback_sp500_securities
      end

      results = []
      results.concat(coingecko_search_securities(clean_symbol))

      if clean_symbol.match?(/\A[A-Z0-9.]{1,6}\z/)
        nasdaq_match = nasdaq_lookup_security(clean_symbol)
        results << nasdaq_match if nasdaq_match
      end

      results
    rescue StandardError
      []
    end

    def fallback_sp500_securities
      coingecko_spyon = coingecko_search_securities("SPYON")
      seen = {}
      (SP500_FALLBACK_SECURITIES.map do |item|
        Provider::SecurityConcept::Security.new(
          symbol: item[:symbol],
          name: item[:name],
          logo_url: nil,
          exchange_operating_mic: item[:mic],
          country_code: item[:country]
        )
      end + coingecko_spyon).select do |sec|
        key = sec.symbol.upcase
        next false if seen[key]

        seen[key] = true
      end
    end

    def fallback_security_prices(symbol, exchange_operating_mic, start_date, end_date)
      if symbol.end_with?("-USD")
        coingecko_prices(symbol, exchange_operating_mic, start_date, end_date)
      elsif exchange_operating_mic.blank? || US_MICS.include?(exchange_operating_mic)
        nasdaq_prices(symbol, exchange_operating_mic, start_date, end_date)
      else
        []
      end
    rescue StandardError
      []
    end

    def fallback_quote_and_series(symbol, exchange_operating_mic, range)
      days = range_to_days(range)
      end_date = Date.current
      start_date = end_date - days.days
      prices = fallback_security_prices(symbol, exchange_operating_mic, start_date, end_date)
      return nil if prices.empty?

      points = prices.map do |p|
        {
          date: p.date,
          price: p.price.to_f.round(4),
          open: nil,
          high: nil,
          low: nil,
          volume: nil
        }
      end

      current_price = points.last[:price]
      prev_close = points.size >= 2 ? points[-2][:price] : nil
      change = (current_price && prev_close) ? (current_price - prev_close).round(4) : nil
      change_pct = (change && prev_close&.nonzero?) ? ((change / prev_close) * 100).round(2) : nil

      Provider::YahooFinance::QuoteSeries.new(
        symbol: symbol,
        name: symbol,
        short_name: symbol,
        currency: prices.last.currency || "USD",
        exchange_name: exchange_operating_mic,
        instrument_type: symbol.end_with?("-USD") ? "CRYPTOCURRENCY" : "EQUITY",
        current_price: current_price,
        previous_close: prev_close,
        change: change,
        change_percent: change_pct,
        day_high: nil,
        day_low: nil,
        fifty_two_week_high: nil,
        fifty_two_week_low: nil,
        volume: nil,
        prices: points
      )
    rescue StandardError
      nil
    end

    def coingecko_search_securities(query)
      resp = fallback_http_client.get("#{COINGECKO_BASE_URL}/search") do |req|
        req.params["query"] = query
      end
      return [] unless resp.status == 200

      coins = JSON.parse(resp.body)["coins"] || []
      coins.first(8).filter_map do |coin|
        sym = coin["symbol"].to_s.strip.upcase
        next if sym.blank?

        Provider::SecurityConcept::Security.new(
          symbol: sym.end_with?("-USD") ? sym : "#{sym}-USD",
          name: coin["name"].presence || sym,
          logo_url: coin["large"] || coin["thumb"],
          exchange_operating_mic: nil,
          country_code: nil
        )
      end
    rescue StandardError
      []
    end

    def coingecko_coin_id(base_symbol)
      cache_key = "coingecko_coin_id:#{base_symbol.upcase}"
      cached = Rails.cache.read(cache_key)
      return cached if cached.present?

      resp = fallback_http_client.get("#{COINGECKO_BASE_URL}/search") do |req|
        req.params["query"] = base_symbol
      end
      return nil unless resp.status == 200

      coins = JSON.parse(resp.body)["coins"] || []
      match = coins.find { |c| c["symbol"].to_s.upcase == base_symbol.upcase }
      coin_id = match&.dig("id")
      Rails.cache.write(cache_key, coin_id, expires_in: 24.hours) if coin_id.present?
      coin_id
    rescue StandardError
      nil
    end

    def coingecko_prices(symbol, exchange_operating_mic, start_date, end_date)
      base = symbol.delete_suffix("-USD")
      coin_id = coingecko_coin_id(base)
      return [] if coin_id.blank?

      days = [ (Date.current - start_date).to_i + 2, 2 ].max
      resp = fallback_http_client.get("#{COINGECKO_BASE_URL}/coins/#{ERB::Util.url_encode(coin_id)}/market_chart") do |req|
        req.params["vs_currency"] = "usd"
        req.params["days"] = days
        req.params["interval"] = "daily"
      end
      return [] unless resp.status == 200

      raw_prices = JSON.parse(resp.body)["prices"] || []
      by_date = {}
      raw_prices.each do |ts_ms, val|
        next if val.nil? || val.to_f <= 0

        d = Time.at(ts_ms.to_f / 1000.0).utc.to_date
        next if d < start_date || d > end_date

        by_date[d] = val.to_f
      end

      if end_date >= Date.current
        live = coingecko_live_price(coin_id)
        by_date[Date.current] = live if live&.positive?
      end

      by_date.sort_by { |d, _| d }.map do |d, price_val|
        Provider::SecurityConcept::Price.new(
          symbol: symbol,
          date: d,
          price: price_val,
          currency: "USD",
          exchange_operating_mic: exchange_operating_mic
        )
      end
    rescue StandardError
      []
    end

    def coingecko_live_price(coin_id)
      resp = fallback_http_client.get("#{COINGECKO_BASE_URL}/simple/price") do |req|
        req.params["ids"] = coin_id
        req.params["vs_currencies"] = "usd"
      end
      return nil unless resp.status == 200

      JSON.parse(resp.body).dig(coin_id, "usd")&.to_f
    rescue StandardError
      nil
    end

    def nasdaq_lookup_security(symbol)
      %w[etf stocks].each do |asset_class|
        resp = fallback_http_client.get("#{NASDAQ_BASE_URL}/quote/#{ERB::Util.url_encode(symbol)}/info") do |req|
          req.params["assetclass"] = asset_class
        end
        next unless resp.status == 200

        data = JSON.parse(resp.body)["data"]
        next unless data.is_a?(Hash) && data["symbol"].present?

        return Provider::SecurityConcept::Security.new(
          symbol: data["symbol"].to_s.upcase,
          name: data["companyName"].presence || symbol,
          logo_url: nil,
          exchange_operating_mic: data["isNasdaqListed"] ? "XNAS" : "ARCX",
          country_code: "US"
        )
      end
      nil
    rescue StandardError
      nil
    end

    def nasdaq_prices(symbol, exchange_operating_mic, start_date, end_date)
      %w[etf stocks].each do |asset_class|
        resp = fallback_http_client.get("#{NASDAQ_BASE_URL}/quote/#{ERB::Util.url_encode(symbol)}/historical") do |req|
          req.params["assetclass"] = asset_class
          req.params["fromdate"] = start_date.iso8601
          req.params["todate"] = end_date.iso8601
          req.params["limit"] = [ (end_date - start_date).to_i + 10, 30 ].max
        end
        next unless resp.status == 200

        rows = JSON.parse(resp.body).dig("data", "tradesTable", "rows")
        next unless rows.is_a?(Array) && rows.any?

        by_date = {}
        rows.each do |row|
          price_val = row["close"].to_s.delete("$, ").to_f
          next unless price_val.positive?

          d = Date.strptime(row["date"], "%m/%d/%Y") rescue nil
          next unless d && d >= start_date && d <= end_date

          by_date[d] = price_val
        end

        if end_date >= Date.current
          live = nasdaq_live_price(symbol, asset_class)
          by_date[Date.current] = live if live&.positive?
        end

        next if by_date.empty?

        return by_date.sort_by { |d, _| d }.map do |d, price_val|
          Provider::SecurityConcept::Price.new(
            symbol: symbol,
            date: d,
            price: price_val,
            currency: "USD",
            exchange_operating_mic: exchange_operating_mic
          )
        end
      end
      []
    rescue StandardError
      []
    end

    def nasdaq_live_price(symbol, asset_class)
      resp = fallback_http_client.get("#{NASDAQ_BASE_URL}/quote/#{ERB::Util.url_encode(symbol)}/info") do |req|
        req.params["assetclass"] = asset_class
      end
      return nil unless resp.status == 200

      raw = JSON.parse(resp.body).dig("data", "primaryData", "lastSalePrice").to_s
      val = raw.delete("$, ").to_f
      val.positive? ? val : nil
    rescue StandardError
      nil
    end

    def range_to_days(range)
      case range.to_s
      when "1d" then 2
      when "5d" then 7
      when "1mo" then 32
      when "3mo" then 95
      when "6mo" then 185
      when "ytd" then (Date.current - Date.current.beginning_of_year).to_i + 5
      when "1y" then 366
      when "5y" then 1830
      else 32
      end
    end

    def fallback_http_client
      @fallback_http_client ||= Faraday.new(ssl: self.class.faraday_ssl_options) do |faraday|
        faraday.headers["User-Agent"] = Provider::YahooFinance::USER_AGENTS.first
        faraday.headers["Accept"] = "application/json"
        faraday.options.timeout = 6
        faraday.options.open_timeout = 3
      end
    end
end
