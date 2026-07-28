class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_authentication

  def plaid
    webhook_body = request.body.read
    plaid_verification_header = request.headers["Plaid-Verification"]

    client = Provider::Registry.plaid_provider_for_region(:us)

    client.validate_webhook!(plaid_verification_header, webhook_body)

    PlaidItem::WebhookProcessor.new(webhook_body).process

    render json: { received: true }, status: :ok
  rescue => error
    Sentry.capture_exception(error)
    Rails.logger.error("Webhook error: #{error.class} - #{error.message}")
    render json: { error: "Invalid webhook" }, status: :bad_request
  end

  def plaid_eu
    webhook_body = request.body.read
    plaid_verification_header = request.headers["Plaid-Verification"]

    client = Provider::Registry.plaid_provider_for_region(:eu)

    client.validate_webhook!(plaid_verification_header, webhook_body)

    PlaidItem::WebhookProcessor.new(webhook_body).process

    render json: { received: true }, status: :ok
  rescue => error
    Sentry.capture_exception(error)
    Rails.logger.error("Webhook error: #{error.class} - #{error.message}")
    render json: { error: "Invalid webhook" }, status: :bad_request
  end

  def stripe
    stripe_provider = Provider::Registry.get_provider(:stripe)

    begin
      webhook_body = request.body.read
      sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

      stripe_provider.process_webhook_later(webhook_body, sig_header)

      head :ok
    rescue JSON::ParserError => error
      Sentry.capture_exception(error)
      Rails.logger.error "JSON parser error: #{error.message}"
      head :bad_request
    rescue Stripe::SignatureVerificationError => error
      Sentry.capture_exception(error)
      Rails.logger.error "Stripe signature verification error: #{error.message}"
      head :bad_request
    end
  end

  def android_purchase
    authenticate_android_webhook!
    return if performed?

    result = AndroidPurchase::WebhookProcessor.new(android_purchase_params).process

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

    def authenticate_android_webhook!
      expected = ENV["ANDROID_WEBHOOK_TOKEN"]

      if expected.blank?
        render json: { error: "Android webhook not configured" }, status: :service_unavailable
        return
      end

      token = request.headers["Authorization"]&.delete_prefix("Bearer ")&.strip

      unless token.present? && ActiveSupport::SecurityUtils.secure_compare(token, expected)
        render json: { error: "unauthorized" }, status: :unauthorized
      end
    end

    def android_purchase_params
      params.permit(:account_id, :amount, :merchant, :item, :timestamp, :raw_text)
    end
end
