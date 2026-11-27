class InvestmentsController < ApplicationController
  include AccountableResource

  permitted_accountable_attributes :id, :subtype

  skip_before_action :set_account, only: %i[index quote quote_lookup sync new_trade create_trade]
  skip_before_action :set_manageable_account, only: %i[index quote quote_lookup sync new_trade create_trade]
  skip_before_action :set_link_options, only: %i[index quote quote_lookup sync new_trade create_trade]

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

    selected_security, selected_watchlist = resolve_selected_context(@selected_ticker, @selected_mic)
    overview = Investments::MarketTrackerService.new.market_overview(
      watchlist_indices: @watchlist_indices,
      watchlist_assets: @watchlist_assets,
      holdings: @holdings,
      selected_ticker: @selected_ticker,
      selected_mic: @selected_mic,
      range: @range,
      selected_security: selected_security,
      selected_watchlist: selected_watchlist,
      force_refresh: force_refresh
    )

    @index_quotes = overview[:index_quotes]
    @watchlist_quotes = overview[:watchlist_quotes]
    @holding_quotes = overview[:holding_quotes]
    @featured_quote = overview[:featured_quote] || find_preloaded_quote(@selected_ticker, @selected_mic)

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

  def quote_lookup
    query = params[:ticker].to_s.strip
    if query.blank?
      render json: { found: false, results: [] }
      return
    end

    yf = Provider::YahooFinance.new
    search_resp = yf.search_securities(query)
    matches = search_resp.success? ? (search_resp.data || []).first(6) : []

    primary_symbol = matches.first&.symbol || query.upcase
    card = Investments::MarketTrackerService.new.quote_for(ticker: primary_symbol, range: "1mo", include_details: false)

    results = matches.map do |sec|
      is_primary = sec.symbol.casecmp?(card&.ticker.to_s)
      {
        ticker: sec.symbol,
        name: sec.name,
        exchange_operating_mic: sec.exchange_operating_mic,
        country_code: sec.country_code,
        current_price: is_primary ? card&.current_price : nil,
        currency: is_primary ? card&.currency : nil,
        change_percent: is_primary ? card&.change_percent : nil
      }
    end

    if results.empty? && card&.current_price
      results << {
        ticker: card.ticker,
        name: card.name,
        exchange_operating_mic: nil,
        country_code: nil,
        current_price: card.current_price,
        currency: card.currency,
        change_percent: card.change_percent
      }
    end

    if card&.current_price
      render json: {
        found: true,
        ticker: card.ticker,
        name: card.name,
        currency: card.currency,
        exchange_name: card.exchange_name,
        current_price: card.current_price,
        change_percent: card.change_percent,
        results: results
      }
    else
      render json: { found: results.any?, ticker: primary_symbol, results: results }
    end
  end

  def sync
    redirect_to investments_path(
      ticker: params[:ticker].presence || "^GSPC",
      mic: params[:mic].presence,
      range: Investments::MarketTrackerService.valid_range(params[:range]),
      refresh: "1"
    ), notice: t("investments.index.synced")
  end

  def new_trade
    @investment_accounts = accessible_accounts.visible.where(accountable_type: "Investment").alphabetically
    @selected_account = @investment_accounts.find_by(id: params[:account_id]) || @investment_accounts.first
    @ticker = params[:ticker].to_s.strip.upcase.presence
    @price = params[:price].presence
    @trade_type = %w[buy sell].include?(params[:type]) ? params[:type] : "buy"
  end

  def create_trade
    @investment_accounts = accessible_accounts.visible.where(accountable_type: "Investment").alphabetically
    account = @investment_accounts.find(params[:account_id])
    return unless require_account_permission!(account)

    raw_ticker = params[:ticker].to_s.strip.upcase
    resolved_ticker = raw_ticker.include?("|") ? raw_ticker : "#{raw_ticker}||yahoo_finance"

    @model = Trade::CreateForm.new(
      account: account,
      type: %w[buy sell].include?(params[:type]) ? params[:type] : "buy",
      ticker: resolved_ticker,
      qty: params[:qty],
      price: params[:price],
      fee: params[:fee].presence || 0,
      date: params[:date].presence || Date.current,
      currency: account.currency
    ).create

    if @model.persisted?
      if @model.is_a?(Entry)
        @model.lock_saved_attributes!
        @model.mark_user_modified!
        if @model.trade&.security_id
          strategy = account.linked? ? :reverse : :forward
          Balance::Materializer.new(account, strategy: strategy, security_ids: [ @model.trade.security_id ]).materialize_balances
        end
      end

      redirect_to investments_path(ticker: @model.try(:trade)&.security&.ticker || raw_ticker),
                  notice: t("investments.new_trade.success")
    else
      @selected_account = account
      @ticker = raw_ticker
      @price = params[:price]
      @trade_type = params[:type] || "buy"
      render :new_trade, status: :unprocessable_entity
    end
  end

  private
    def find_preloaded_quote(ticker, mic)
      all_cards = @index_quotes + @watchlist_quotes + @holding_quotes.values
      all_cards.find do |card|
        card.ticker.casecmp?(ticker) && (mic.blank? || card.security&.exchange_operating_mic.to_s.casecmp?(mic))
      end
    end

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
