require "set"

class Provider::YahooFinance < Provider
  include ExchangeRateConcept, SecurityConcept
  extend SslConfigurable

  # Subclass so errors caught in this provider are raised as Provider::YahooFinance::Error
  Error = Class.new(Provider::Error)
  InvalidSecurityPriceError = Class.new(Error)
  RateLimitError = Class.new(Error)
  AuthenticationError = Class.new(Error)
  InvalidSymbolError = Class.new(Error)
  MarketClosedError = Class.new(Error)

  QuoteSeries = Data.define(
    :symbol,
    :name,
    :short_name,
    :currency,
    :exchange_name,
    :instrument_type,
    :current_price,
    :previous_close,
    :change,
    :change_percent,
    :day_high,
    :day_low,
    :fifty_two_week_high,
    :fifty_two_week_low,
    :volume,
    :prices
  )

  QuoteFundamentals = Data.define(
    :market_cap,
    :pe_ratio,
    :forward_pe,
    :eps,
    :dividend_yield,
    :beta,
    :avg_volume,
    :open_price,
    :bid,
    :ask,
    :target_mean_price,
    :recommendation_key,
    :sector,
    :industry,
    :website,
    :description,
    :earnings_date,
    :ex_dividend_date,
    :market_state,
    :pre_market_price,
    :pre_market_change_percent,
    :post_market_price,
    :post_market_change_percent
  )

  NewsItem = Data.define(
    :title,
    :publisher,
    :link,
    :published_at
  )

  # Cache duration for repeated requests (5 minutes)
  CACHE_DURATION = 5.minutes

  # Once Yahoo returns a 429, further requests fail fast for this long instead
  # of each burning a full 5-retry exponential backoff against an endpoint
  # we already know is blocked. Without this, a nightly import over many
  # securities would retry-storm Yahoo security-by-security, taking far
  # longer and likely extending the block.
  RATE_LIMIT_COOLDOWN = 10.minutes

  # Maximum cache duration for cookie/crumb authentication
  # Even if cookie has longer expiry, cap it to avoid stale crumbs
  MAX_CRUMB_CACHE_DURATION = 1.hour

  # Maximum lookback window for historical data (configurable)
  MAX_LOOKBACK_WINDOW = 10.years

  def max_history_days
    (MAX_LOOKBACK_WINDOW / 1.day).to_i
  end

  # Minimum delay between requests to avoid rate limiting (in seconds)
  MIN_REQUEST_INTERVAL = 0.5

  # Pool of modern browser user-agents to rotate through
  # Based on https://github.com/ranaroussi/yfinance/pull/2277
  # UPDATED user-agents string on 2026-02-27 with current versions of browsers (Chrome 145, Firefox 148, Safari 26)
  USER_AGENTS = [
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_4) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:148.0) Gecko/20100101 Firefox/148.0"
  ].freeze

  def initialize
    # Yahoo Finance doesn't require an API key but we may want to add proxy support later
    @cache_prefix = "yahoo_finance"
  end

  def healthy?
    data = fetch_authenticated_chart("AAPL", { "interval" => "1d", "range" => "1d" })
    result = data.dig("chart", "result")
    result.present? && result.any?
  rescue => e
    false
  end

  def usage
    # Yahoo Finance doesn't expose usage data, so we return a mock structure
    with_provider_response do
      usage_data = UsageData.new(
        used: 0,
        limit: 2000, # Estimated daily limit based on community knowledge
        utilization: 0,
        plan: "Free"
      )

      usage_data
    end
  end

  # ================================
  #          Exchange Rates
  # ================================

  def fetch_exchange_rate(from:, to:, date:)
    with_provider_response do
      # Return 1.0 if same currency
      if from == to
        Rate.new(date: date, from: from, to: to, rate: 1.0)
      else
        cache_key = "exchange_rate_#{from}_#{to}_#{date}"
        if cached_result = get_cached_result(cache_key)
          cached_result
        else
          check_rate_limit!
          # For a single date, we'll fetch a range and find the closest match
          end_date = date
          start_date = date - 10.days # Extended range for better coverage

          rates_response = fetch_exchange_rates(
            from: from,
            to: to,
            start_date: start_date,
            end_date: end_date
          )

          raise Error, "Failed to fetch exchange rates: #{rates_response.error.message}" unless rates_response.success?

          rates = rates_response.data
          if rates.length == 1
            rates.first
          else
            # Find the exact date or the closest previous date
            target_rate = rates.find { |r| r.date == date } ||
                         rates.select { |r| r.date <= date }.max_by(&:date)

            raise Error, "No exchange rate found for #{from}/#{to} on or before #{date}" unless target_rate

            cache_result(cache_key, target_rate)
            target_rate
          end
        end
      end
    end
  end

  def fetch_exchange_rates(from:, to:, start_date:, end_date:)
    with_provider_response do
      validate_date_range!(start_date, end_date)
      # Return 1.0 rates if same currency
      if from == to
        generate_same_currency_rates(from, to, start_date, end_date)
      else
        cache_key = "exchange_rates_#{from}_#{to}_#{start_date}_#{end_date}"
        if cached_result = get_cached_result(cache_key)
          cached_result
        else
          check_rate_limit!
          # Try both direct and inverse currency pairs
          rates = fetch_currency_pair_data(from, to, start_date, end_date) ||
                  fetch_inverse_currency_pair_data(from, to, start_date, end_date)

          raise Error, "No chart data found for currency pair #{from}/#{to}" unless rates&.any?

          cache_result(cache_key, rates)
          rates
        end
      end
    rescue JSON::ParserError => e
      raise Error, "Invalid response format: #{e.message}"
    end
  end

  # ================================
  #           Securities
  # ================================

  def search_securities(symbol, country_code: nil, exchange_operating_mic: nil)
    with_provider_response do
      cache_key = "search_#{symbol}_#{country_code}_#{exchange_operating_mic}"
      if cached_result = get_cached_result(cache_key)
        cached_result
      else
        check_rate_limit!
        throttle_request
        response = client.get("#{base_url}/v1/finance/search") do |req|
          req.params["q"] = symbol.strip.upcase
          req.params["quotesCount"] = 25
        end

        data = JSON.parse(response.body)
        quotes = data.dig("quotes") || []

        securities = quotes.filter_map do |quote|
          Security.new(
            symbol: quote["symbol"],
            name: quote["longname"] || quote["shortname"] || quote["symbol"],
            logo_url: nil, # Yahoo search doesn't provide logos
            exchange_operating_mic: map_exchange_mic(quote["exchange"]),
            country_code: map_country_code(quote["exchDisp"])
          )
        end

        securities = deduplicate_dual_listings(securities) unless exchange_operating_mic.present?

        cache_result(cache_key, securities)
        securities
      end
    rescue JSON::ParserError => e
      raise Error, "Invalid search response format: #{e.message}"
    end
  end

  def fetch_security_info(symbol:, exchange_operating_mic:)
    with_provider_response do
      symbol = normalize_symbol(symbol, exchange_operating_mic)

      # quoteSummary endpoint requires cookie/crumb authentication
      check_rate_limit!
      throttle_request
      cookie, crumb = fetch_cookie_and_crumb

      encoded_symbol = ERB::Util.url_encode(symbol)
      response = authenticated_client(cookie).get("#{base_url}/v10/finance/quoteSummary/#{encoded_symbol}") do |req|
        req.params["modules"] = "assetProfile,price,quoteType"
        req.params["crumb"] = crumb
      end

      data = JSON.parse(response.body)

      # Check for auth errors in response body
      if data.dig("quoteSummary", "error", "code") == "Unauthorized"
        # Clear cached crumb and retry once
        clear_crumb_cache
        cookie, crumb = fetch_cookie_and_crumb
        response = authenticated_client(cookie).get("#{base_url}/v10/finance/quoteSummary/#{encoded_symbol}") do |req|
          req.params["modules"] = "assetProfile,price,quoteType"
          req.params["crumb"] = crumb
        end
        data = JSON.parse(response.body)
        if data.dig("quoteSummary", "error", "code") == "Unauthorized"
          raise AuthenticationError, "Yahoo Finance authentication failed after crumb refresh"
        end
      end

      result = data.dig("quoteSummary", "result", 0)

      raise Error, "No security info found for #{symbol}" unless result

      asset_profile = result["assetProfile"] || {}
      price_info = result["price"] || {}
      quote_type = result["quoteType"] || {}

      security_info = SecurityInfo.new(
        symbol: symbol,
        name: price_info["longName"] || price_info["shortName"] || quote_type["longName"] || quote_type["shortName"],
        links: asset_profile["website"],
        logo_url: nil, # Yahoo doesn't provide reliable logo URLs
        description: asset_profile["longBusinessSummary"],
        kind: map_security_type(quote_type["quoteType"]),
        exchange_operating_mic: exchange_operating_mic
      )

      security_info
    rescue JSON::ParserError => e
      raise Error, "Invalid response format: #{e.message}"
    end
  end

  def fetch_security_price(symbol:, exchange_operating_mic: nil, date:)
    with_provider_response do
      symbol = normalize_symbol(symbol, exchange_operating_mic)
      cache_key = "security_price_#{symbol}_#{exchange_operating_mic}_#{date}"
      if cached_result = get_cached_result(cache_key)
        cached_result
      else
        # For a single date, we'll fetch a range and find the closest match
        end_date = date
        start_date = date - 10.days # Extended range for better coverage

        prices_response = fetch_security_prices(
          symbol: symbol,
          exchange_operating_mic: exchange_operating_mic,
          start_date: start_date,
          end_date: end_date
        )

        raise Error, "Failed to fetch security prices: #{prices_response.error.message}" unless prices_response.success?

        prices = prices_response.data
        if prices.length == 1
          target_price = prices.first
        else
          # Find the exact date or the closest previous date
          target_price = prices.find { |p| p.date == date } ||
                        prices.select { |p| p.date <= date }.max_by(&:date)

          raise Error, "No price found for #{symbol} on or before #{date}" unless target_price
        end

        cache_result(cache_key, target_price)
        target_price
      end
    end
  end

  def fetch_security_prices(symbol:, exchange_operating_mic: nil, start_date:, end_date:)
    with_provider_response do
      symbol = normalize_symbol(symbol, exchange_operating_mic)
      validate_date_params!(start_date, end_date)
      check_rate_limit!
      # Convert dates to Unix timestamps using UTC to ensure consistent epoch boundaries across timezones
      period1 = start_date.to_time.utc.to_i
      period2 = end_date.end_of_day.to_time.utc.to_i

      throttle_request
      data = fetch_authenticated_chart(symbol, {
        "period1" => period1,
        "period2" => period2,
        "interval" => "1d",
        "includeAdjustedClose" => true
      })

      chart_data = data.dig("chart", "result", 0)

      raise Error, "No chart data found for #{symbol}" unless chart_data

      timestamps = chart_data.dig("timestamp") || []
      quotes = chart_data.dig("indicators", "quote", 0) || {}
      closes = quotes["close"] || []

      # Get currency from metadata
      meta_exchange = chart_data.dig("meta", "exchangeName") || ""
      raw_currency = chart_data.dig("meta", "currency")
      raw_currency ||= default_currency_for_exchange(meta_exchange) || "USD"

      prices = []
      timestamps.each_with_index do |timestamp, index|
        close_price = closes[index]
        next if close_price.nil? # Skip days with no data (weekends, holidays)

        # Normalize currency and price to handle minor units
        normalized_currency, normalized_price = normalize_currency_and_price(raw_currency, close_price.to_f)

        prices << Price.new(
          symbol: symbol,
          date: Time.at(timestamp).utc.to_date,
          price: normalized_price,
          currency: normalized_currency,
          exchange_operating_mic: exchange_operating_mic
        )
      end

      sorted_prices = prices.sort_by(&:date)
      sorted_prices
    rescue JSON::ParserError => e
      raise Error, "Invalid response format: #{e.message}"
    end
  end

  def fetch_quote_and_series(symbol:, exchange_operating_mic: nil, range: "1mo", interval: "1d", clear_cache: false)
    with_provider_response do
      normalized_sym = normalize_symbol(symbol, exchange_operating_mic)
      intraday = %w[1m 2m 5m 15m 30m 60m 90m 1h].include?(interval.to_s)
      cache_key = "quote_series_#{normalized_sym}_#{range}_#{interval}"

      if !clear_cache && (cached = get_cached_result(cache_key))
        cached
      else
        data = fetch_chart_with_fallback(normalized_sym, {
          "range" => range,
          "interval" => interval,
          "includePrePost" => intraday
        })

        if (err = data.dig("chart", "error"))
          raise Error, err["description"] || err["code"] || "Chart error for #{normalized_sym}"
        end

        chart_data = data.dig("chart", "result", 0)
        raise Error, "No chart data found for #{normalized_sym}" unless chart_data

        meta = chart_data["meta"] || {}
        timestamps = chart_data["timestamp"] || []
        quotes = chart_data.dig("indicators", "quote", 0) || {}
        closes = quotes["close"] || []
        opens = quotes["open"] || []
        highs = quotes["high"] || []
        lows = quotes["low"] || []
        volumes = quotes["volume"] || []

        meta_exchange = meta["exchangeName"] || ""
        raw_currency = meta["currency"] || default_currency_for_exchange(meta_exchange) || "USD"

        series_points = {}
        timestamps.each_with_index do |ts, idx|
          close_val = closes[idx]
          next if close_val.nil? || close_val.to_f <= 0

          point_key = intraday ? Time.at(ts).utc : Time.at(ts).utc.to_date
          norm_curr, norm_price = normalize_currency_and_price(raw_currency, close_val.to_f)
          raw_currency = norm_curr

          _, norm_open = opens[idx] ? normalize_currency_and_price(raw_currency, opens[idx].to_f) : [ norm_curr, nil ]
          _, norm_high = highs[idx] ? normalize_currency_and_price(raw_currency, highs[idx].to_f) : [ norm_curr, nil ]
          _, norm_low = lows[idx] ? normalize_currency_and_price(raw_currency, lows[idx].to_f) : [ norm_curr, nil ]

          series_points[point_key] = {
            date: point_key,
            price: norm_price.round(4),
            open: norm_open&.round(4),
            high: norm_high&.round(4),
            low: norm_low&.round(4),
            volume: volumes[idx]&.to_i
          }
        end

        points = series_points.sort_by { |d, _| d }.map { |_, pt| pt }

        raw_regular = meta["regularMarketPrice"]&.to_f
        norm_curr, regular_price = raw_regular ? normalize_currency_and_price(raw_currency, raw_regular) : [ raw_currency, points.last&.dig(:price) ]
        raw_prev = (meta["previousClose"] || meta["chartPreviousClose"])&.to_f
        _, prev_close = raw_prev ? normalize_currency_and_price(raw_currency, raw_prev) : [ norm_curr, nil ]

        # Fallback to second-to-last close when Yahoo omits previousClose on multi-day ranges
        if prev_close.nil? && points.size >= 2
          prev_close = points[-2][:price]
        end

        change = (regular_price && prev_close) ? (regular_price - prev_close).round(4) : nil
        change_pct = (change && prev_close&.nonzero?) ? ((change / prev_close) * 100).round(2) : nil

        _, day_high = meta["regularMarketDayHigh"] ? normalize_currency_and_price(raw_currency, meta["regularMarketDayHigh"].to_f) : [ norm_curr, nil ]
        _, day_low = meta["regularMarketDayLow"] ? normalize_currency_and_price(raw_currency, meta["regularMarketDayLow"].to_f) : [ norm_curr, nil ]
        _, week52_high = meta["fiftyTwoWeekHigh"] ? normalize_currency_and_price(raw_currency, meta["fiftyTwoWeekHigh"].to_f) : [ norm_curr, nil ]
        _, week52_low = meta["fiftyTwoWeekLow"] ? normalize_currency_and_price(raw_currency, meta["fiftyTwoWeekLow"].to_f) : [ norm_curr, nil ]

        quote_series = QuoteSeries.new(
          symbol: normalized_sym,
          name: meta["longName"] || meta["shortName"] || normalized_sym,
          short_name: meta["shortName"] || meta["longName"] || normalized_sym,
          currency: norm_curr,
          exchange_name: meta["fullExchangeName"] || meta["exchangeName"],
          instrument_type: meta["instrumentType"],
          current_price: regular_price&.round(4),
          previous_close: prev_close&.round(4),
          change: change,
          change_percent: change_pct,
          day_high: day_high&.round(4),
          day_low: day_low&.round(4),
          fifty_two_week_high: week52_high&.round(4),
          fifty_two_week_low: week52_low&.round(4),
          volume: meta["regularMarketVolume"]&.to_i,
          prices: points
        )

        cache_result(cache_key, quote_series)
        quote_series
      end
    rescue JSON::ParserError => e
      raise Error, "Invalid response format: #{e.message}"
    end
  end

  def fetch_quote_summary(symbol:, exchange_operating_mic: nil, clear_cache: false)
    with_provider_response do
      normalized_sym = normalize_symbol(symbol, exchange_operating_mic)
      cache_key = "quote_summary_#{normalized_sym}"

      if !clear_cache && (cached = get_cached_result(cache_key))
        cached
      else
        check_rate_limit!
        throttle_request
        cookie, crumb = fetch_cookie_and_crumb

        encoded_symbol = ERB::Util.url_encode(normalized_sym)
        modules = "summaryDetail,defaultKeyStatistics,financialData,assetProfile,calendarEvents,price"
        response = authenticated_client(cookie).get("#{base_url}/v10/finance/quoteSummary/#{encoded_symbol}") do |req|
          req.params["modules"] = modules
          req.params["crumb"] = crumb
        end

        data = JSON.parse(response.body)
        if data.dig("quoteSummary", "error", "code") == "Unauthorized"
          clear_crumb_cache
          cookie, crumb = fetch_cookie_and_crumb
          response = authenticated_client(cookie).get("#{base_url}/v10/finance/quoteSummary/#{encoded_symbol}") do |req|
            req.params["modules"] = modules
            req.params["crumb"] = crumb
          end
          data = JSON.parse(response.body)
          raise AuthenticationError, "Yahoo Finance authentication failed" if data.dig("quoteSummary", "error", "code") == "Unauthorized"
        end

        result = data.dig("quoteSummary", "result", 0)
        raise Error, "No quote summary found for #{normalized_sym}" unless result

        summary = result["summaryDetail"] || {}
        stats = result["defaultKeyStatistics"] || {}
        financial = result["financialData"] || {}
        profile = result["assetProfile"] || {}
        calendar = result["calendarEvents"] || {}
        price = result["price"] || {}

        earnings_ts = yahoo_raw(calendar.dig("earnings", "earningsDate", 0))
        ex_div_ts = yahoo_raw(summary["exDividendDate"]) || yahoo_raw(calendar["exDividendDate"])

        fundamentals = QuoteFundamentals.new(
          market_cap: yahoo_raw(price["marketCap"]) || yahoo_raw(summary["marketCap"]),
          pe_ratio: yahoo_raw(summary["trailingPE"]),
          forward_pe: yahoo_raw(summary["forwardPE"]) || yahoo_raw(stats["forwardPE"]),
          eps: yahoo_raw(stats["trailingEps"]),
          dividend_yield: yahoo_raw(summary["dividendYield"]) || yahoo_raw(summary["trailingAnnualDividendYield"]),
          beta: yahoo_raw(summary["beta"]) || yahoo_raw(stats["beta"]),
          avg_volume: yahoo_raw(summary["averageVolume"])&.to_i,
          open_price: yahoo_raw(summary["open"]) || yahoo_raw(price["regularMarketOpen"]),
          bid: yahoo_raw(summary["bid"]),
          ask: yahoo_raw(summary["ask"]),
          target_mean_price: yahoo_raw(financial["targetMeanPrice"]),
          recommendation_key: financial["recommendationKey"],
          sector: profile["sector"],
          industry: profile["industry"],
          website: profile["website"],
          description: profile["longBusinessSummary"],
          earnings_date: earnings_ts ? Time.at(earnings_ts.to_i).utc.to_date.to_s : nil,
          ex_dividend_date: ex_div_ts ? Time.at(ex_div_ts.to_i).utc.to_date.to_s : nil,
          market_state: price["marketState"],
          pre_market_price: yahoo_raw(price["preMarketPrice"]),
          pre_market_change_percent: yahoo_raw(price["preMarketChangePercent"])&.then { |v| (v * 100).round(2) },
          post_market_price: yahoo_raw(price["postMarketPrice"]),
          post_market_change_percent: yahoo_raw(price["postMarketChangePercent"])&.then { |v| (v * 100).round(2) }
        )

        cache_result(cache_key, fundamentals)
        fundamentals
      end
    rescue JSON::ParserError => e
      raise Error, "Invalid quoteSummary response format: #{e.message}"
    end
  end

  def fetch_news(query: "^GSPC", count: 6, clear_cache: false)
    with_provider_response do
      clean_query = query.to_s.strip.presence || "^GSPC"
      cache_key = "news_#{clean_query}_#{count}"

      if !clear_cache && (cached = get_cached_result(cache_key))
        cached
      else
        check_rate_limit!
        throttle_request
        response = client.get("#{base_url}/v1/finance/search") do |req|
          req.params["q"] = clean_query
          req.params["quotesCount"] = 0
          req.params["newsCount"] = count
        end

        data = JSON.parse(response.body)
        items = (data["news"] || []).filter_map do |item|
          next if item["title"].blank? || item["link"].blank?

          ts = item["providerPublishTime"]
          NewsItem.new(
            title: item["title"],
            publisher: item["publisher"].presence || "Yahoo Finance",
            link: item["link"],
            published_at: ts ? Time.at(ts.to_i).utc.iso8601 : nil
          )
        end

        cache_result(cache_key, items)
        items
      end
    rescue JSON::ParserError => e
      raise Error, "Invalid news response format: #{e.message}"
    end
  end

  private

    def yahoo_raw(field)
      return nil if field.nil?

      field.is_a?(Hash) ? field["raw"] : field
    end

    def base_url
      ENV["YAHOO_FINANCE_URL"] || "https://query1.finance.yahoo.com"
    end

    # Fetches /v8/finance/chart/:symbol preferring query2 (which serves chart
    # data without cookie/crumb and is far less prone to 429s), falling back
    # to authenticated query1 if needed.
    def fetch_chart_with_fallback(symbol, params)
      encoded_symbol = ERB::Util.url_encode(symbol)
      [ "https://query2.finance.yahoo.com", base_url ].uniq.each do |host|
        throttle_request
        response = client.get("#{host}/v8/finance/chart/#{encoded_symbol}") do |req|
          params.each { |k, v| req.params[k] = v }
        end
        next if response.status == 429 || response.status == 401

        parsed = JSON.parse(response.body)
        return parsed if parsed.dig("chart", "result", 0).present?
      rescue Faraday::Error, JSON::ParserError
        next
      end

      check_rate_limit!
      throttle_request
      fetch_authenticated_chart(symbol, params)
    end

    # ================================
    #      Currency Normalization
    # ================================

    # Per-exchange configuration for Yahoo Finance.  Each entry maps an ISO
    # MIC code to its Yahoo-specific symbol suffix, the default currency when
    # Yahoo omits one, and an optional dual-listing group with a preference
    # rank (lower = preferred).  Adding a new market is a one-line hash entry.
    EXCHANGE_CONFIG = {
      "XNSE" => { yahoo_suffix: ".NS", default_currency: "INR", dual_list_group: :india, preference_rank: 0 },
      "XBOM" => { yahoo_suffix: ".BO", default_currency: "INR", dual_list_group: :india, preference_rank: 1 }
    }.freeze

    # Yahoo Finance sometimes returns currencies in minor units (pence, cents)
    # This is not part of ISO 4217 but is a convention used by financial data providers
    # Mapping of Yahoo Finance minor unit codes to standard currency codes and conversion multipliers
    MINOR_CURRENCY_CONVERSIONS = {
      "GBp" => { currency: "GBP", multiplier: 0.01 },  # British pence to pounds (eg. https://finance.yahoo.com/quote/IITU.L/)
      "ZAc" => { currency: "ZAR", multiplier: 0.01 }   # South African cents to rand (eg. https://finance.yahoo.com/quote/JSE.JO)
    }.freeze

    # Normalizes Yahoo Finance currency codes and prices
    # Returns [currency_code, price] with currency converted to standard ISO code
    # and price converted from minor units to major units if applicable
    def normalize_currency_and_price(currency, price)
      if conversion = MINOR_CURRENCY_CONVERSIONS[currency]
        [ conversion[:currency], price * conversion[:multiplier] ]
      else
        [ currency, price ]
      end
    end

    # Appends the Yahoo Finance symbol suffix for exchanges that require one
    # (e.g. XNSE → ".NS", XBOM → ".BO").  Already-suffixed symbols pass through.
    def normalize_symbol(symbol, exchange_operating_mic)
      suffix = EXCHANGE_CONFIG.dig(exchange_operating_mic, :yahoo_suffix)
      return symbol if suffix.nil? || symbol.end_with?(suffix)
      "#{symbol}#{suffix}"
    end

    # Returns the default currency for a Yahoo exchange name (e.g. "NSE" → "INR")
    # by resolving through map_exchange_mic → EXCHANGE_CONFIG.  Returns nil for
    # unknown exchanges so callers can fall back to their own default.
    def default_currency_for_exchange(yahoo_exchange_name)
      mic = map_exchange_mic(yahoo_exchange_name)
      EXCHANGE_CONFIG.dig(mic, :default_currency)
    end

    # De-duplicates dual-listed securities that share the same company name
    # and dual_list_group (e.g. NSE + BSE for India), keeping the exchange
    # with the lowest preference_rank.  Preserves Yahoo's original relevance
    # ordering by removing duplicates in-place rather than reordering.
    def deduplicate_dual_listings(securities)
      dominated = Set.new

      securities
        .select { |s| EXCHANGE_CONFIG.dig(s.exchange_operating_mic, :dual_list_group) }
        .group_by { |s| [ EXCHANGE_CONFIG[s.exchange_operating_mic][:dual_list_group], s.name.to_s.strip.downcase ] }
        .each_value do |group|
          next unless group.size > 1
          preferred = group.min_by { |s| EXCHANGE_CONFIG[s.exchange_operating_mic][:preference_rank] }
          group.each { |s| dominated << s.object_id unless s.equal?(preferred) }
        end

      return securities if dominated.empty?
      securities.reject { |s| dominated.include?(s.object_id) }
    end

    # ================================
    #           Validation
    # ================================


    def validate_date_range!(start_date, end_date)
      raise Error, "Start date cannot be after end date" if start_date > end_date
      raise Error, "Date range too large (max 5 years)" if end_date > start_date + 5.years
    end

    def validate_date_params!(start_date, end_date)
      # Validate presence and coerce to dates
      validated_start_date = validate_and_coerce_date!(start_date, "start_date")
      validated_end_date = validate_and_coerce_date!(end_date, "end_date")

      # Ensure start_date <= end_date
      if validated_start_date > validated_end_date
        error_msg = "Start date (#{validated_start_date}) cannot be after end date (#{validated_end_date})"
        raise ArgumentError, error_msg
      end

      # Ensure end_date is not in the future
      today = Date.current
      if validated_end_date > today
        error_msg = "End date (#{validated_end_date}) cannot be in the future"
        raise ArgumentError, error_msg
      end

      # Optional: Enforce max lookback window (configurable via constant)
      max_lookback = MAX_LOOKBACK_WINDOW.ago.to_date
      if validated_start_date < max_lookback
        error_msg = "Start date (#{validated_start_date}) exceeds maximum lookback window (#{max_lookback})"
        raise ArgumentError, error_msg
      end
    end

    def validate_and_coerce_date!(date_param, param_name)
      # Check presence
      if date_param.blank?
        error_msg = "#{param_name} cannot be blank"
        raise ArgumentError, error_msg
      end

      # Try to coerce to date
      begin
        if date_param.respond_to?(:to_date)
          date_param.to_date
        else
          Date.parse(date_param.to_s)
        end
      rescue ArgumentError => e
        error_msg = "Invalid #{param_name}: #{date_param} (#{e.message})"
        raise ArgumentError, error_msg
      end
    end

    # ================================
    #           Caching
    # ================================

    def rate_limit_cache_key
      "#{@cache_prefix}_rate_limited_until"
    end

    def rate_limited?
      Rails.cache.read(rate_limit_cache_key).present?
    end

    def check_rate_limit!
      raise RateLimitError, "Yahoo Finance rate limit exceeded (cooling down, retry later)" if rate_limited?
    end

    def mark_rate_limited!
      Rails.cache.write(rate_limit_cache_key, true, expires_in: RATE_LIMIT_COOLDOWN)
    end

    def get_cached_result(key)
      full_key = "#{@cache_prefix}_#{key}"
      data = Rails.cache.read(full_key)
      data
    end

    def cache_result(key, data)
      full_key = "#{@cache_prefix}_#{key}"
      Rails.cache.write(full_key, data, expires_in: CACHE_DURATION)
    end



    # ================================
    #         Helper Methods
    # ================================

    def generate_same_currency_rates(from, to, start_date, end_date)
      (start_date..end_date).map do |date|
        Rate.new(date: date, from: from, to: to, rate: 1.0)
      end
    end

    def fetch_currency_pair_data(from, to, start_date, end_date)
      symbol = "#{from}#{to}=X"
      fetch_chart_data(symbol, start_date, end_date) do |timestamp, close_rate|
        Rate.new(
          date: Time.at(timestamp).utc.to_date,
          from: from,
          to: to,
          rate: close_rate.to_f
        )
      end
    end

    def fetch_inverse_currency_pair_data(from, to, start_date, end_date)
      symbol = "#{to}#{from}=X"
      rates = fetch_chart_data(symbol, start_date, end_date) do |timestamp, close_rate|
        Rate.new(
          date: Time.at(timestamp).utc.to_date,
          from: from,
          to: to,
          rate: (BigDecimal("1") / BigDecimal(close_rate.to_s)).round(12)
        )
      end

      rates
    end

    # Makes a single authenticated GET to /v8/finance/chart/:symbol.
    # If Yahoo returns a stale-crumb error (200 OK with Unauthorized body),
    # clears the crumb cache and retries once with fresh credentials.
    def fetch_authenticated_chart(symbol, params)
      encoded_symbol = ERB::Util.url_encode(symbol)
      cookie, crumb = fetch_cookie_and_crumb
      response = authenticated_client(cookie).get("#{base_url}/v8/finance/chart/#{encoded_symbol}") do |req|
        params.each { |k, v| req.params[k] = v }
        req.params["crumb"] = crumb
      end
      data = JSON.parse(response.body)

      if data.dig("chart", "error", "code") == "Unauthorized"
        clear_crumb_cache
        cookie, crumb = fetch_cookie_and_crumb
        response = authenticated_client(cookie).get("#{base_url}/v8/finance/chart/#{encoded_symbol}") do |req|
          params.each { |k, v| req.params[k] = v }
          req.params["crumb"] = crumb
        end
        data = JSON.parse(response.body)
        if data.dig("chart", "error", "code") == "Unauthorized"
          raise AuthenticationError, "Yahoo Finance authentication failed after crumb refresh"
        end
      end

      data
    end

    def fetch_chart_data(symbol, start_date, end_date, &block)
      period1 = start_date.to_time.utc.to_i
      period2 = end_date.end_of_day.to_time.utc.to_i

      begin
        throttle_request
        data = fetch_authenticated_chart(symbol, {
          "period1" => period1,
          "period2" => period2,
          "interval" => "1d",
          "includeAdjustedClose" => true
        })

        # Check for Yahoo Finance errors
        if data.dig("chart", "error")
          return nil
        end

        chart_data = data.dig("chart", "result", 0)
        return nil unless chart_data

        timestamps = chart_data.dig("timestamp") || []
        quotes = chart_data.dig("indicators", "quote", 0) || {}
        closes = quotes["close"] || []

        results = []
        timestamps.each_with_index do |timestamp, index|
          close_value = closes[index]
          next if close_value.nil? || close_value <= 0

          results << block.call(timestamp, close_value)
        end

        results.sort_by(&:date)
      rescue Faraday::Error, JSON::ParserError => e
        nil
      end
    end

    def client
      @client ||= Faraday.new(url: base_url, ssl: self.class.faraday_ssl_options) do |faraday|
        faraday.request(:retry, {
          max: max_retries,
          interval: retry_interval,
          interval_randomness: 0.5,
          backoff_factor: 2,
          retry_statuses: [ 429 ],
          exceptions: [ Faraday::ConnectionFailed, Faraday::TimeoutError ]
        })

        faraday.request :json
        faraday.response :raise_error

        # Yahoo Finance requires common browser headers to avoid blocking
        # Rotate user-agents to reduce rate limiting (based on yfinance PR #2277)
        faraday.headers["User-Agent"] = random_user_agent
        faraday.headers["Accept"] = "application/json"
        faraday.headers["Accept-Language"] = "en-US,en;q=0.9"
        faraday.headers["Cache-Control"] = "no-cache"
        faraday.headers["Pragma"] = "no-cache"

        # Set reasonable timeouts
        faraday.options.timeout = 10
        faraday.options.open_timeout = 5
      end
    end

    def random_user_agent
      USER_AGENTS.sample
    end

    def max_retries
      ENV.fetch("YAHOO_FINANCE_MAX_RETRIES", 5).to_i
    end

    def retry_interval
      ENV.fetch("YAHOO_FINANCE_RETRY_INTERVAL", 1.0).to_f
    end

    def min_request_interval
      ENV.fetch("YAHOO_FINANCE_MIN_REQUEST_INTERVAL", MIN_REQUEST_INTERVAL).to_f
    end

    def throttle_request
      @last_request_time ||= Time.at(0)
      elapsed = Time.current - @last_request_time
      sleep_time = min_request_interval - elapsed
      sleep(sleep_time) if sleep_time > 0
      @last_request_time = Time.current
    end

    # ================================
    #    Cookie/Crumb Authentication
    # ================================

    # Fetches and caches the Yahoo Finance cookie and crumb for authenticated endpoints
    # The crumb is a CSRF token required by some Yahoo Finance endpoints (e.g., quoteSummary)
    def fetch_cookie_and_crumb
      cache_key = "#{@cache_prefix}_auth_crumb"
      cached = Rails.cache.read(cache_key)
      return cached if cached.present?

      # Step 1: Get cookie from Yahoo Finance
      cookie_response = auth_client.get("https://fc.yahoo.com")
      cookie = extract_cookie(cookie_response)
      cookie_max_age = extract_cookie_max_age(cookie_response)

      raise AuthenticationError, "Failed to obtain Yahoo Finance cookie" if cookie.blank?

      # Step 2: Get crumb using the cookie
      crumb_response = auth_client.get("#{base_url}/v1/test/getcrumb") do |req|
        req.headers["Cookie"] = cookie
      end

      crumb = crumb_response.body.strip

      raise AuthenticationError, "Failed to obtain Yahoo Finance crumb" if crumb.blank?

      # Cache the cookie/crumb pair using cookie's max-age, capped at MAX_CRUMB_CACHE_DURATION
      cache_duration = [ cookie_max_age || MAX_CRUMB_CACHE_DURATION, MAX_CRUMB_CACHE_DURATION ].min
      result = [ cookie, crumb ]
      Rails.cache.write(cache_key, result, expires_in: cache_duration)
      result
    rescue Faraday::Error => e
      raise AuthenticationError, "Failed to authenticate with Yahoo Finance: #{e.message}"
    end

    def clear_crumb_cache
      Rails.cache.delete("#{@cache_prefix}_auth_crumb")
    end

    # Extract the authentication cookie from Yahoo Finance response
    def extract_cookie(response)
      set_cookie = response.headers["set-cookie"]
      return nil if set_cookie.blank?

      # Extract the cookie value (format: "A3=d=xxx&S=xxx; Max-Age=31557600; ...")
      # We only need the part before the first semicolon
      set_cookie.split(";").first
    end

    # Extract Max-Age from cookie header and convert to seconds
    # Format: "...; Max-Age=31557600; ..."
    def extract_cookie_max_age(response)
      set_cookie = response.headers["set-cookie"]
      return nil if set_cookie.blank?

      max_age_match = set_cookie.match(/Max-Age=(\d+)/i)
      return nil unless max_age_match

      max_age_match[1].to_i.seconds
    end

    # Client for authentication requests (no error raising - fc.yahoo.com returns 404 but sets cookie)
    def auth_client
      @auth_client ||= Faraday.new(ssl: self.class.faraday_ssl_options) do |faraday|
        faraday.headers["User-Agent"] = random_user_agent
        faraday.headers["Accept"] = "*/*"
        faraday.headers["Accept-Language"] = "en-US,en;q=0.9"
        faraday.options.timeout = 10
        faraday.options.open_timeout = 5
      end
    end

    # Client for authenticated requests (includes cookie header)
    def authenticated_client(cookie)
      Faraday.new(url: base_url, ssl: self.class.faraday_ssl_options) do |faraday|
        faraday.request(:retry, {
          max: max_retries,
          interval: retry_interval,
          interval_randomness: 0.5,
          backoff_factor: 2,
          retry_statuses: [ 429 ],
          exceptions: [ Faraday::ConnectionFailed, Faraday::TimeoutError ]
        })

        faraday.request :json
        faraday.response :raise_error

        faraday.headers["User-Agent"] = random_user_agent
        faraday.headers["Accept"] = "application/json"
        faraday.headers["Accept-Language"] = "en-US,en;q=0.9"
        faraday.headers["Cache-Control"] = "no-cache"
        faraday.headers["Pragma"] = "no-cache"
        faraday.headers["Cookie"] = cookie

        faraday.options.timeout = 10
        faraday.options.open_timeout = 5
      end
    end

    def map_country_code(exchange_name)
      return nil if exchange_name.blank?

      # Map common exchange names to country codes
      case exchange_name.upcase.strip
      when /NASDAQ|NYSE|AMEX|BATS|IEX/
        "US"
      when /TSX|TSXV|CSE/
        "CA"
      when /LSE|LONDON|AIM/
        "GB"
      when /TOKYO|TSE|NIKKEI|JASDAQ/
        "JP"
      when /ASX|AUSTRALIA/
        "AU"
      when /EURONEXT|PARIS|AMSTERDAM|BRUSSELS|LISBON/
        case exchange_name.upcase
        when /PARIS/ then "FR"
        when /AMSTERDAM/ then "NL"
        when /BRUSSELS/ then "BE"
        when /LISBON/ then "PT"
        else "FR" # Default to France for Euronext
        end
      when /FRANKFURT|XETRA|GETTEX/
        "DE"
      when /SIX|ZURICH/
        "CH"
      when /BME|MADRID/
        "ES"
      when /BORSA|MILAN/
        "IT"
      when /OSLO|OSE/
        "NO"
      when /STOCKHOLM|OMX/
        "SE"
      when /COPENHAGEN/
        "DK"
      when /HELSINKI/
        "FI"
      when /VIENNA/
        "AT"
      when /WARSAW|GPW/
        "PL"
      when /PRAGUE/
        "CZ"
      when /BUDAPEST/
        "HU"
      when /SHANGHAI|SHENZHEN/
        "CN"
      when /HONG\s*KONG|HKG/
        "HK"
      when /KOREA|KRX/
        "KR"
      when /SINGAPORE|SGX/
        "SG"
      when /MUMBAI|NSE|BSE/
        "IN"
      when /SAO\s*PAULO|BOVESPA/
        "BR"
      when /MEXICO|BMV/
        "MX"
      when /JSE|JOHANNESBURG/
        "ZA"
      else
        nil
      end
    end

    def map_exchange_mic(exchange_code)
      return nil if exchange_code.blank?

      # Map Yahoo exchange codes to MIC codes
      case exchange_code.upcase.strip
      when "NMS"
        "XNAS" # NASDAQ Global Select
      when "NGM"
        "XNAS" # NASDAQ Global Market
      when "NCM"
        "XNAS" # NASDAQ Capital Market
      when "NYQ"
        "XNYS" # NYSE
      when "PCX", "PSX"
        "ARCX" # NYSE Arca
      when "ASE", "AMX"
        "XASE" # NYSE American
      when "YHD"
        "XNAS" # Yahoo default, assume NASDAQ
      when "TSE", "TOR"
        "XTSE" # Toronto Stock Exchange
      when "CVE"
        "XTSX" # TSX Venture Exchange
      when "LSE", "LON"
        "XLON" # London Stock Exchange
      when "FRA"
        "XFRA" # Frankfurt Stock Exchange
      when "PAR"
        "XPAR" # Euronext Paris
      when "AMS"
        "XAMS" # Euronext Amsterdam
      when "BRU"
        "XBRU" # Euronext Brussels
      when "SWX"
        "XSWX" # SIX Swiss Exchange
      when "HKG"
        "XHKG" # Hong Kong Stock Exchange
      when "TYO"
        "XJPX" # Japan Exchange Group
      when "ASX"
        "XASX" # Australian Securities Exchange
      when "NSE", "NSI"
        "XNSE" # National Stock Exchange of India
      when "BSE", "BOM"
        "XBOM" # BSE (Bombay Stock Exchange)
      else
        exchange_code.upcase
      end
    end

    def map_security_type(quote_type)
      case quote_type&.downcase
      when "equity"
        "common stock"
      when "etf"
        "etf"
      when "mutualfund"
        "mutual fund"
      when "index"
        "index"
      else
        quote_type&.downcase
      end
    end

    # Override default error transformer to handle Yahoo Finance specific errors
    def default_error_transformer(error)
      case error
      when Faraday::TooManyRequestsError
        mark_rate_limited!
        RateLimitError.new("Yahoo Finance rate limit exceeded", details: error.response&.dig(:body))
      when Faraday::UnauthorizedError
        # 401 indicates missing or invalid crumb/cookie authentication
        AuthenticationError.new("Yahoo Finance authentication failed (invalid crumb)", details: error.response&.dig(:body))
      when AuthenticationError
        # Already an authentication error, return as is
        error
      when Faraday::Error
        Error.new(
          error.message,
          details: error.response&.dig(:body)
        )
      when Error
        # Already a Yahoo Finance error, return as is
        error
      else
        Error.new(error.message)
      end
    end
end
