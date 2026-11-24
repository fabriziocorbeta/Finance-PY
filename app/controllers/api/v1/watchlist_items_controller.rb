# frozen_string_literal: true

class Api::V1::WatchlistItemsController < Api::V1::BaseController
  before_action :ensure_write_scope

  # POST /api/v1/watchlist_items
  def create
    ticker = params[:ticker].to_s.strip.upcase
    if ticker.blank?
      render_validation_error("Ticker is required", [ "ticker can't be blank" ])
      return
    end

    mic = params[:exchange_operating_mic].presence
    security = Security.find_or_initialize_by(ticker: ticker, exchange_operating_mic: mic)
    security.price_provider ||= "yahoo_finance"
    security.offline = false
    security.save!

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
    item = current_family.watchlist_items.find_or_initialize_by(security: security)
    item.category = category
    item.position ||= current_family.watchlist_items.maximum(:position).to_i + 1
    item.save!

    render json: {
      watchlist_item: {
        id: item.id,
        ticker: security.ticker,
        name: security.name || quote&.name || security.ticker,
        category: item.category
      }
    }, status: :created
  rescue => e
    log_and_render_error("create", e)
  end

  # DELETE /api/v1/watchlist_items/:id
  def destroy
    item = current_family.watchlist_items.find(params[:id])
    item.destroy!
    render json: { deleted: true }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: "not_found", message: "Watchlist item not found" }, status: :not_found
  rescue => e
    log_and_render_error("destroy", e)
  end

  private
    def ensure_write_scope
      authorize_scope!(:read_write)
    end
end
