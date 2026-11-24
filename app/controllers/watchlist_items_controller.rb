class WatchlistItemsController < ApplicationController
  def create
    security = resolve_or_create_security
    unless security
      redirect_to investments_path, alert: t("watchlist_items.create.not_found")
      return
    end

    quote = Investments::MarketTrackerService.new.quote_for(
      ticker: security.ticker,
      exchange_operating_mic: security.exchange_operating_mic,
      range: "1mo",
      security: security
    )

    if security.name.blank? && quote&.name.present?
      security.update(name: quote.name)
    end

    category = quote&.category || WatchlistItem.infer_category(ticker: security.ticker)
    item = Current.family.watchlist_items.find_or_initialize_by(security: security)
    item.category = category
    item.position ||= Current.family.watchlist_items.maximum(:position).to_i + 1
    item.save!

    redirect_to investments_path(ticker: security.ticker, mic: security.exchange_operating_mic),
                notice: t("watchlist_items.create.success", ticker: security.ticker)
  end

  def destroy
    item = Current.family.watchlist_items.find(params[:id])
    ticker = item.ticker
    item.destroy!

    respond_to do |format|
      format.html { redirect_to investments_path, notice: t("watchlist_items.destroy.success", ticker: ticker) }
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(helpers.dom_id(item))
      end
    end
  end

  private
    def resolve_or_create_security
      if params[:security_id].present?
        parsed = Security.parse_combobox_id(params[:security_id])
        return nil if parsed[:ticker].blank?

        security = Security.find_or_initialize_by(
          ticker: parsed[:ticker],
          exchange_operating_mic: parsed[:exchange_operating_mic]
        )
        security.price_provider = parsed[:price_provider].presence || "yahoo_finance"
        security.offline = false
        security.save!
        security
      elsif params[:ticker].present?
        ticker = params[:ticker].strip.upcase
        mic = params[:exchange_operating_mic].presence

        security = Security.find_or_initialize_by(ticker: ticker, exchange_operating_mic: mic)
        security.price_provider ||= "yahoo_finance"
        security.offline = false
        security.save!
        security
      end
    end
end
