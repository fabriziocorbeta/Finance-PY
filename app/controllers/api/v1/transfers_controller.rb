# frozen_string_literal: true

class Api::V1::TransfersController < Api::V1::BaseController
  before_action :ensure_write_scope

  # POST /api/v1/transfers
  # Registers a payment/transfer between two accounts of the same family
  # (e.g. paying down a receivable, a credit card, a loan).
  def create
    family = current_resource_owner.family
    source_account = family.accounts.find(transfer_params[:from_account_id])
    destination_account = family.accounts.find(transfer_params[:to_account_id])

    @transfer = Transfer::Creator.new(
      family: family,
      source_account_id: source_account.id,
      destination_account_id: destination_account.id,
      date: transfer_params[:date].present? ? Date.parse(transfer_params[:date]) : Date.current,
      amount: transfer_params[:amount].to_d,
      exchange_rate: transfer_params[:exchange_rate].presence&.to_d
    ).create

    if @transfer.persisted?
      @transfer.sync_account_later
      render :show, status: :created
    else
      render json: {
        error: "validation_failed",
        message: "Transfer could not be created",
        errors: @transfer.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: "not_found", message: "Account not found" }, status: :not_found
  rescue Money::ConversionError
    render json: {
      error: "validation_failed",
      message: "Exchange rate unavailable for selected currencies and date",
      errors: [ "Exchange rate unavailable for selected currencies and date" ]
    }, status: :unprocessable_entity
  rescue ArgumentError => e
    render json: { error: "validation_failed", message: e.message, errors: [ e.message ] }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "TransfersController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def transfer_params
      params.require(:transfer).permit(:from_account_id, :to_account_id, :amount, :date, :exchange_rate)
    end
end
