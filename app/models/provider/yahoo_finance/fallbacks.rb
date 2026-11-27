module Provider::YahooFinance::Fallbacks
  extend ActiveSupport::Concern

  COINGECKO_BASE_URL = "https://api.coingecko.com/api/v3".freeze
  NASDAQ_BASE_URL = "https://api.nasdaq.com/api".freeze
  CNBC_QUOTE_URL = "https://quote.cnbc.com/quote-html-webservice/restQuote/symbolType/symbol".freeze
  CNBC_BARS_BASE_URL = "https://ts-api.cnbc.com/harmony/app/bars".freeze
  US_MICS = %w[XNAS XNYS ARCX XASE BATS IEX].freeze

  COINGECKO_KNOWN_IDS = {
    "SPYON" => "spdr-s-p-500-etf-ondo-tokenized-etf",
    "QQQON" => "invesco-qqq-etf-ondo-tokenized-etf",
    "SOXXON" => "ishares-semiconductor-etf-ondo-tokenized",
    "BTC" => "bitcoin",
    "ETH" => "ethereum"
  }.freeze

  CNBC_SYMBOL_MAP = {
    "^GSPC" => ".SPX",
    "^IXIC" => ".IXIC",
    "^DJI" => ".DJI",
    "^VIX" => ".VIX",
    "^RUT" => ".RUT",
    "^FTSE" => ".FTSE",
    "^N225" => ".N225",
    "^GDAXI" => ".GDAXI",
    "^FCHI" => ".FCHI",
    "^BVSP" => ".BVSP",
    "^MERV" => ".MERV",
    "GC=F" => "@GC.1",
    "SI=F" => "@SI.1",
    "CL=F" => "@CL.1",
    "BZ=F" => "@LCO.1",
    "NG=F" => "@NG.1",
    "HG=F" => "@HG.1",
    "PYG=X" => "PYG="
  }.freeze

  CNBC_DEFAULT_BATCH_SYMBOLS = %w[.SPX .IXIC .DJI .VIX @GC.1 @CL.1 PYG=].freeze
  CNBC_BATCH_MUTEX = Mutex.new

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
      SP500_FALLBACK_SECURITIES.map do |item|
        Provider::SecurityConcept::Security.new(
          symbol: item[:symbol],
          name: item[:name],
          logo_url: nil,
          exchange_operating_mic: item[:mic],
          country_code: item[:country]
        )
      end
    end

    def fallback_security_prices(symbol, exchange_operating_mic, start_date, end_date)
      if symbol.end_with?("-USD")
        coingecko_prices(symbol, exchange_operating_mic, start_date, end_date)
      elsif (cnbc_sym = cnbc_symbol_for(symbol))
        cnbc_prices(symbol, cnbc_sym, exchange_operating_mic, start_date, end_date)
      elsif us_equity_ticker?(symbol) && (exchange_operating_mic.blank? || US_MICS.include?(exchange_operating_mic))
        nasdaq_prices(symbol, exchange_operating_mic, start_date, end_date)
      else
        []
      end
    rescue StandardError
      []
    end

    def fallback_quote_and_series(symbol, exchange_operating_mic, range)
      if (cnbc_sym = cnbc_symbol_for(symbol))
        cnbc_series = cnbc_quote_and_series(symbol, cnbc_sym, exchange_operating_mic, range)
        return cnbc_series if cnbc_series
      end

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

    def us_equity_ticker?(symbol)
      symbol.to_s.match?(/\A[A-Z]{1,5}([.-][A-Z])?\z/)
    end

    def cnbc_symbol_for(symbol)
      upper = symbol.to_s.upcase
      return CNBC_SYMBOL_MAP[upper] if CNBC_SYMBOL_MAP.key?(upper)

      if upper.match?(/\AUSD([A-Z]{3})=X\z/)
        "#{Regexp.last_match(1)}="
      elsif upper.match?(/\A([A-Z]{3})=X\z/)
        "#{Regexp.last_match(1)}="
      end
    end

    def cnbc_quote_and_series(symbol, cnbc_sym, exchange_operating_mic, range)
      days = range_to_days(range)
      end_date = Date.current
      start_date = end_date - days.days

      quote_meta = cnbc_live_quote_for(cnbc_sym)
      bars = cnbc_bars(cnbc_sym, start_date, end_date)
      return nil if quote_meta.nil? && bars.empty?

      currency = quote_meta&.dig(:currency) || default_cnbc_currency(symbol)
      points = bars.map do |b|
        {
          date: b[:date],
          price: b[:close],
          open: b[:open],
          high: b[:high],
          low: b[:low],
          volume: b[:volume]
        }
      end

      live_last = quote_meta&.dig(:last)
      if live_last && (points.empty? || points.last[:date] < Date.current)
        points << {
          date: Date.current,
          price: live_last,
          open: nil,
          high: quote_meta[:high],
          low: quote_meta[:low],
          volume: quote_meta[:volume]
        }
      elsif live_last && points.last
        points[-1] = points[-1].merge(price: live_last)
      end

      return nil if points.empty?

      current_price = live_last || points.last[:price]
      prev_close = quote_meta&.dig(:prev_close) || (points.size >= 2 ? points[-2][:price] : nil)
      change = quote_meta&.dig(:change) || ((current_price && prev_close) ? (current_price - prev_close).round(4) : nil)
      change_pct = quote_meta&.dig(:change_pct) || ((change && prev_close&.nonzero?) ? ((change / prev_close) * 100).round(2) : nil)

      Provider::YahooFinance::QuoteSeries.new(
        symbol: symbol,
        name: quote_meta&.dig(:name).presence || symbol,
        short_name: quote_meta&.dig(:short_name).presence || symbol,
        currency: currency,
        exchange_name: quote_meta&.dig(:exchange).presence || exchange_operating_mic,
        instrument_type: cnbc_instrument_type(symbol),
        current_price: current_price,
        previous_close: prev_close,
        change: change,
        change_percent: change_pct,
        day_high: quote_meta&.dig(:high),
        day_low: quote_meta&.dig(:low),
        fifty_two_week_high: quote_meta&.dig(:week52_high),
        fifty_two_week_low: quote_meta&.dig(:week52_low),
        volume: quote_meta&.dig(:volume),
        prices: points
      )
    rescue StandardError
      nil
    end

    def cnbc_prices(symbol, cnbc_sym, exchange_operating_mic, start_date, end_date)
      bars = cnbc_bars(cnbc_sym, start_date, end_date)
      currency = default_cnbc_currency(symbol)
      bars.map do |b|
        Provider::SecurityConcept::Price.new(
          symbol: symbol,
          date: b[:date],
          price: b[:close],
          currency: currency,
          exchange_operating_mic: exchange_operating_mic
        )
      end
    rescue StandardError
      []
    end

    def cnbc_bars(cnbc_sym, start_date, end_date)
      cache_key = "cnbc_bars:#{cnbc_sym}:#{start_date.iso8601}:#{end_date.iso8601}"
      cached = Rails.cache.read(cache_key)
      return cached if cached.is_a?(Array)

      d1 = (start_date - 3.days).strftime("%Y%m%d000000")
      d2 = (end_date + 1.day).strftime("%Y%m%d000000")
      url = "#{CNBC_BARS_BASE_URL}/#{ERB::Util.url_encode(cnbc_sym)}/1D/#{d1}/#{d2}/adjusted/EST5EDT.json"
      resp = fallback_http_client.get(url)
      return [] unless resp.status == 200

      raw_bars = JSON.parse(resp.body).dig("barData", "priceBars") || []
      by_date = {}
      raw_bars.each do |bar|
        close_val = parse_cnbc_positive(bar["close"])
        next unless close_val

        trade_str = bar["tradeTime"].to_s[0, 8]
        d = Date.strptime(trade_str, "%Y%m%d") rescue nil
        next unless d && d >= start_date && d <= end_date

        vol = bar["volume"].to_s.delete(",").to_i
        by_date[d] = {
          date: d,
          close: close_val,
          open: parse_cnbc_positive(bar["open"]),
          high: parse_cnbc_positive(bar["high"]),
          low: parse_cnbc_positive(bar["low"]),
          volume: vol.positive? ? vol : nil
        }
      end

      bars = by_date.sort_by { |d, _| d }.map(&:last)
      Rails.cache.write(cache_key, bars, expires_in: Provider::YahooFinance::LIVE_QUOTE_CACHE_DURATION) if bars.any?
      bars
    rescue StandardError
      []
    end

    def cnbc_live_quote_for(cnbc_sym)
      if CNBC_DEFAULT_BATCH_SYMBOLS.include?(cnbc_sym)
        batch = fetch_cnbc_default_batch
        return batch[cnbc_sym] if batch&.key?(cnbc_sym)
      end

      cache_key = "cnbc_quote:#{cnbc_sym}"
      cached = Rails.cache.read(cache_key)
      return cached if cached

      parsed = request_cnbc_quotes([ cnbc_sym ])[cnbc_sym]
      Rails.cache.write(cache_key, parsed, expires_in: Provider::YahooFinance::LIVE_QUOTE_CACHE_DURATION) if parsed
      parsed
    rescue StandardError
      nil
    end

    def fetch_cnbc_default_batch
      cache_key = "cnbc_quote_default_batch"
      cached = Rails.cache.read(cache_key)
      return cached if cached.is_a?(Hash)

      return request_cnbc_quotes(CNBC_DEFAULT_BATCH_SYMBOLS) if Rails.env.test?

      CNBC_BATCH_MUTEX.synchronize do
        again = Rails.cache.read(cache_key)
        return again if again.is_a?(Hash)

        batch = request_cnbc_quotes(CNBC_DEFAULT_BATCH_SYMBOLS)
        Rails.cache.write(cache_key, batch, expires_in: Provider::YahooFinance::LIVE_QUOTE_CACHE_DURATION) if batch.any?
        batch
      end
    end

    def request_cnbc_quotes(symbols)
      resp = fallback_http_client.get(CNBC_QUOTE_URL) do |req|
        req.params["symbols"] = symbols.join("|")
        req.params["requestMethod"] = "itv"
        req.params["noform"] = "1"
        req.params["partnerId"] = "2"
        req.params["fund"] = "1"
        req.params["exthrs"] = "1"
        req.params["output"] = "json"
        req.params["events"] = "1"
      end
      return {} unless resp.status == 200

      raw = JSON.parse(resp.body).dig("FormattedQuoteResult", "FormattedQuote")
      items = raw.is_a?(Array) ? raw : [ raw ].compact
      items.each_with_object({}) do |q, acc|
        sym = q["symbol"].to_s
        last = parse_cnbc_positive(q["last"])
        next if sym.blank? || last.nil?

        vol = q["volume"].to_s.delete(",").to_i
        acc[sym] = {
          name: q["name"],
          short_name: q["shortName"],
          currency: q["currencyCode"].presence,
          exchange: q["exchange"].presence,
          last: last,
          prev_close: parse_cnbc_positive(q["previous_day_closing"]),
          change: parse_cnbc_signed(q["change"]),
          change_pct: parse_cnbc_signed(q["change_pct"]),
          high: parse_cnbc_positive(q["high"]),
          low: parse_cnbc_positive(q["low"]),
          week52_high: parse_cnbc_positive(q["yrhiprice"]),
          week52_low: parse_cnbc_positive(q["yrloprice"]),
          volume: vol.positive? ? vol : nil
        }
      end
    rescue StandardError
      {}
    end

    def parse_cnbc_positive(raw)
      return nil if raw.nil?

      cleaned = raw.to_s.gsub(/[^0-9.\-+]/, "")
      return nil if cleaned.blank?

      val = cleaned.to_f
      val.positive? ? val.round(4) : nil
    end

    def parse_cnbc_signed(raw)
      return nil if raw.nil?

      cleaned = raw.to_s.gsub(/[^0-9.\-+]/, "")
      return nil if cleaned.blank? || cleaned == "-" || cleaned == "+"

      cleaned.to_f.round(4)
    end

    def default_cnbc_currency(symbol)
      upper = symbol.to_s.upcase
      if upper.match?(/\A(?:USD)?([A-Z]{3})=X\z/)
        Regexp.last_match(1)
      else
        "USD"
      end
    end

    def cnbc_instrument_type(symbol)
      upper = symbol.to_s.upcase
      if upper.start_with?("^")
        "INDEX"
      elsif upper.end_with?("=F")
        "FUTURE"
      elsif upper.end_with?("=X")
        "CURRENCY"
      else
        "EQUITY"
      end
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
      upper = base_symbol.upcase
      return COINGECKO_KNOWN_IDS[upper] if COINGECKO_KNOWN_IDS.key?(upper)

      cache_key = "coingecko_coin_id:#{upper}"
      cached = Rails.cache.read(cache_key)
      return cached if cached.present?

      resp = fallback_http_client.get("#{COINGECKO_BASE_URL}/search") do |req|
        req.params["query"] = base_symbol
      end
      return nil unless resp.status == 200

      coins = JSON.parse(resp.body)["coins"] || []
      match = coins.find { |c| c["symbol"].to_s.upcase == upper }
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
      cache_key = "coingecko_market_chart:#{coin_id}:#{days}"
      raw_prices = Rails.cache.read(cache_key)

      if raw_prices.nil?
        resp = fallback_http_client.get("#{COINGECKO_BASE_URL}/coins/#{ERB::Util.url_encode(coin_id)}/market_chart") do |req|
          req.params["vs_currency"] = "usd"
          req.params["days"] = days
          req.params["interval"] = "daily"
        end
        return [] unless resp.status == 200

        raw_prices = JSON.parse(resp.body)["prices"] || []
        Rails.cache.write(cache_key, raw_prices, expires_in: Provider::YahooFinance::LIVE_QUOTE_CACHE_DURATION) if raw_prices.any?
      end

      by_date = {}
      raw_prices.each do |ts_ms, val|
        next if val.nil? || val.to_f <= 0

        d = Time.at(ts_ms.to_f / 1000.0).utc.to_date
        next if d < start_date || d > end_date

        by_date[d] = val.to_f
      end

      if end_date >= Date.current && !by_date.key?(Date.current)
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
      when "1d" then 5
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
        faraday.options.timeout = 3.5
        faraday.options.open_timeout = 2
      end
    end
end
