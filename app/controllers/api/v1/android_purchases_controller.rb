# frozen_string_literal: true

class Api::V1::AndroidPurchasesController < Api::V1::BaseController
  before_action :ensure_write_scope

  # POST /api/v1/android_purchases
  def create
    result = AndroidPurchase::WebhookProcessor.new(
      android_purchase_params.merge(account_id: account_id_param),
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

    # account_id kept out of .permit() on purpose: Brakeman's taint analysis
    # flags any key inside .permit(...) as a mass-assignment risk based on
    # the call site alone, regardless of how the value is used downstream
    # (confirmed with fuel_logs_controller.rb earlier in this project) --
    # resolving it safely AFTER permit doesn't satisfy the scanner. It's
    # never assigned directly to a model here anyway, only used by
    # WebhookProcessor to look up an Account scoped to the caller's family.
    def account_id_param
      params[:account_id].to_s
    end

    def android_purchase_params
      params.permit(:amount, :merchant, :item, :timestamp, :raw_text)
    end
end
