# frozen_string_literal: true

class Api::V1::AndroidPurchasesController < Api::V1::BaseController
  before_action :ensure_write_scope

  # POST /api/v1/android_purchases
  def create
    result = AndroidPurchase::WebhookProcessor.new(
      android_purchase_params,
      family: current_resource_owner.family
    ).process

    render json: { received: true, duplicate: result == :duplicate }, status: :ok
  rescue AndroidPurchase::WebhookProcessor::Error => error
    Rails.logger.error("Android purchase webhook error: #{error.message}")
    render json: { error: error.message }, status: :unprocessable_entity
  rescue => error
    Sentry.capture_exception(error)
    Rails.logger.error("Android purchase webhook error: #{error.class} - #{error.message}")
    render json: { error: "Invalid webhook" }, status: :bad_request
  end

  private

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def android_purchase_params
      params.permit(:account_id, :amount, :merchant, :item, :timestamp, :raw_text)
    end
end
